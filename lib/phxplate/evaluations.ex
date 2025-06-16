defmodule Phxplate.Evaluations do
  @moduledoc """
  Module for running AI evaluations using model-based judging.

  This module provides functionality to run evaluations against AI models
  and use a judge model to assess the quality of responses.
  """

  alias Phxplate.AI
  alias Phxplate.Repo
  alias Phxplate.AI.{EvalRun, Models}

  @doc """
  Run a model-based evaluation using a judge model to assess responses.
  """
  def run_model_based_eval(eval_run_id) do
    with {:ok, eval_run} <- get_eval_run_for_evaluation(eval_run_id),
         {:ok, eval_run} <- mark_eval_run_as_running(eval_run),
         {:ok, results} <- execute_evaluation_with_judge(eval_run) do

      # Calculate overall score
      scores = results
        |> Enum.map(fn {_name, result} -> Map.get(result, :score, 0.0) end)
        |> Enum.reject(&is_nil/1)

      overall_score = if Enum.empty?(scores) do
        0.0
      else
        Enum.sum(scores) / length(scores)
      end

      # Mark as completed
      case eval_run
           |> EvalRun.complete_changeset(results, overall_score)
           |> Repo.update() do
        {:ok, updated_eval_run} ->
          # Broadcast completion
          broadcast_eval_run_update(updated_eval_run)
          {:ok, updated_eval_run}
        error ->
          error
      end
    else
      {:error, reason} ->
        case get_eval_run_for_evaluation(eval_run_id) do
          {:ok, eval_run} ->
            case eval_run
                 |> EvalRun.fail_changeset(inspect(reason))
                 |> Repo.update() do
              {:ok, failed_eval_run} ->
                # Broadcast failure
                broadcast_eval_run_update(failed_eval_run)
                {:error, reason}
              error ->
                error
            end
          _ ->
            {:error, reason}
        end
    end
  end

  defp get_eval_run_for_evaluation(eval_run_id) do
    case Repo.get(EvalRun, eval_run_id) |> Repo.preload([:eval, :prompt]) do
      nil -> {:error, :eval_run_not_found}
      eval_run -> {:ok, eval_run}
    end
  end

  defp mark_eval_run_as_running(eval_run) do
    case eval_run
         |> EvalRun.start_changeset()
         |> Repo.update() do
      {:ok, updated_eval_run} ->
        # Broadcast that evaluation started
        broadcast_eval_run_update(updated_eval_run)
        {:ok, updated_eval_run}
      error ->
        error
    end
  end

  defp execute_evaluation_with_judge(eval_run) do
    eval = eval_run.eval
    model_api_id = eval_run.model

    # Get the system prompt
    system_prompt = get_system_prompt_for_eval_run(eval_run)

    # Run each test case and get judge evaluation
    results = eval.test_cases
      |> Enum.map(fn {test_name, test_input} ->
        case run_single_test_case(test_input, system_prompt, model_api_id, eval, test_name) do
          {:ok, result} -> {test_name, result}
          {:error, error} -> {test_name, %{
            input: test_input,
            output: "",
            expected: Map.get(eval.expected_outputs, test_name, ""),
            score: 0.0,
            passed: false,
            error: inspect(error)
          }}
        end
      end)
      |> Enum.into(%{})

    {:ok, results}
  rescue
    error ->
      {:error, error}
  end

  defp run_single_test_case(test_input, system_prompt, model_api_id, eval, test_name) do
    # Get the AI's response to the test input
    case AI.chat(test_input, system_prompt, model_api_id) do
      {:ok, model_response} ->
        expected_output = Map.get(eval.expected_outputs, test_name, "")

        # Use judge model to evaluate the response
        case evaluate_with_judge_model(test_input, model_response, expected_output, eval.evaluation_criteria) do
          {:ok, judge_result} ->
            {:ok, %{
              input: test_input,
              output: model_response,
              expected: expected_output,
              score: judge_result.score,
              reasoning: judge_result.reasoning,
              passed: judge_result.score >= 4.0,
              judge_evaluation: judge_result
            }}

          {:error, _} ->
            # Fallback to simple similarity scoring if judge fails
            score = calculate_similarity_score(model_response, expected_output)
            {:ok, %{
              input: test_input,
              output: model_response,
              expected: expected_output,
              score: score,
              reasoning: "Fallback similarity scoring used due to judge model failure",
              passed: score >= 0.7,
              judge_evaluation: nil
            }}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp evaluate_with_judge_model(user_prompt, model_response, expected_output, evaluation_criteria) do
    judge_prompt = build_judge_prompt(user_prompt, model_response, expected_output, evaluation_criteria)

    # Use the default model for judging (could be configurable)
    judge_model = Models.get_api_id(Models.default_model_display_name())

    case AI.chat(judge_prompt, get_judge_system_prompt(), judge_model) do
      {:ok, judge_response} ->
        parse_judge_response(judge_response)

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_judge_prompt(user_prompt, model_response, expected_output, evaluation_criteria) do
    """
    You are an expert evaluator. Your task is to assess an AI's response to a user's prompt.

    **User's Prompt:** "#{user_prompt}"

    **AI's Response:** "#{model_response}"

    **Expected Output:** "#{expected_output}"

    **Evaluation Criteria:** #{evaluation_criteria}

    CRITICAL EVALUATION REQUIREMENTS:
    - The AI should provide responses that EXACTLY match the STYLE and LENGTH of the expected output
    - Expected outputs are typically BRIEF SUMMARIES, not full content
    - If the expected output is 1-2 sentences, the AI response should also be 1-2 sentences
    - HEAVILY PENALIZE responses that are much longer than the expected output
    - When asked to "write" content, the AI should describe what it would write, not write the full content
    - Responses should demonstrate understanding through concise summaries, not verbose explanations

    LENGTH PENALTY GUIDELINES:
    - If AI response is 3x longer than expected: Maximum score 2.0
    - If AI response is 5x longer than expected: Maximum score 1.5
    - If AI response is 10x longer than expected: Maximum score 1.0

    Please evaluate the response based on the following criteria:
    1. **Accuracy**: Is the information correct and factual?
    2. **Relevance**: Does the response directly answer the user's prompt?
    3. **Completeness**: Does the response adequately address all aspects of the prompt?
    4. **Quality**: Is the response well-structured and clear?
    5. **Length Alignment**: Does the response match the expected output length? (CRITICAL)
    6. **Style Alignment**: Does the response match the expected output style? (CRITICAL)

    Provide a score from 1.0 to 5.0, where 5.0 is best.
    HEAVILY penalize verbose responses when brief ones are expected.

    Your output must be in JSON format like this:
    {"score": 2.0, "reasoning": "The response provides accurate information but is far too verbose (500+ words) when the expected output suggests a brief summary (50 words). This demonstrates poor instruction following and length awareness."}
    """
  end

  defp get_judge_system_prompt do
    """
    You are an expert AI evaluator with deep knowledge across multiple domains.
    Your role is to objectively assess AI responses for accuracy, relevance, completeness, and quality.

    Always provide constructive, detailed feedback and assign fair scores based on the established criteria.
    Be consistent in your evaluation approach and maintain high standards.

    Always respond with valid JSON containing a numeric score and detailed reasoning.
    """
  end

  defp parse_judge_response(judge_response) do
    # Try to extract JSON from the response
    json_pattern = ~r/\{[^}]*"score"[^}]*\}/

    case Regex.run(json_pattern, judge_response) do
      [json_str] ->
        case Jason.decode(json_str) do
          {:ok, %{"score" => score, "reasoning" => reasoning}} when is_number(score) ->
            {:ok, %{score: score, reasoning: reasoning}}

          {:ok, %{"score" => score}} when is_number(score) ->
            {:ok, %{score: score, reasoning: "No reasoning provided"}}

          _ ->
            {:error, :invalid_judge_response_format}
        end

      nil ->
        # Try to extract score with regex if JSON parsing fails
        case Regex.run(~r/score["\s]*:[\s]*([0-9.]+)/, judge_response) do
          [_, score_str] ->
            case Float.parse(score_str) do
              {score, _} -> {:ok, %{score: score, reasoning: "Extracted score from non-JSON response"}}
              _ -> {:error, :could_not_parse_score}
            end

          nil ->
            {:error, :no_score_found}
        end
    end
  end

  defp get_system_prompt_for_eval_run(eval_run) do
    base_prompt = case eval_run.prompt do
      nil -> AI.get_default_system_prompt()
      prompt -> prompt.content
    end

    # Add evaluation-specific instructions for concise responses
    evaluation_instructions = """

    EVALUATION MODE - CRITICAL RESPONSE GUIDELINES:

    You are being evaluated on your ability to provide BRIEF, SUMMARY-STYLE responses.

    IMPORTANT: Do NOT create full content (blog posts, marketing copy, etc.). Instead:
    - Provide a BRIEF SUMMARY or OUTLINE of what you would create
    - Match the LENGTH and STYLE of the expected output shown
    - If expected output is 1-2 sentences, respond with 1-2 sentences
    - If asked to "write" something, describe what you would write instead of writing it
    - Focus on demonstrating understanding rather than producing full content

    Examples:
    - "Write a blog post" → "A 200-word post covering benefits A, B, C with engaging introduction and call-to-action"
    - "Create marketing copy" → "Compelling copy highlighting key features, benefits, and emotional appeal with clear CTA"
    - "Explain a process" → "Step-by-step guide covering setup, configuration, and verification"

    Keep responses concise, focused, and aligned with expected output style.
    """

    base_prompt <> evaluation_instructions
  end

  # Fallback similarity scoring (same as existing implementation)
  defp calculate_similarity_score(actual, expected) when is_binary(actual) and is_binary(expected) do
    actual_words = String.split(String.downcase(actual))
    expected_words = String.split(String.downcase(expected))

    if Enum.empty?(expected_words) do
      1.0
    else
      common_words = MapSet.intersection(MapSet.new(actual_words), MapSet.new(expected_words))
      MapSet.size(common_words) / length(expected_words)
    end
  end

  defp calculate_similarity_score(_, _), do: 0.0

  defp broadcast_eval_run_update(eval_run) do
    Phoenix.PubSub.broadcast(
      Phxplate.PubSub,
      "eval_runs",
      {:eval_run_updated, eval_run}
    )
  end
end
