defmodule Phxplate.Evaluations do
  @moduledoc """
  Module for running AI evaluations using model-based judging.

  This module provides functionality to run evaluations against AI models
  and use a judge model to assess the quality of responses.
  """

  alias Phxplate.AI
  alias Phxplate.Repo
  alias Phxplate.AI.{EvalRun, Models}
  import Ecto.Query

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
      eval_run
      |> EvalRun.complete_changeset(results, overall_score)
      |> Repo.update()
    else
      {:error, reason} ->
        case get_eval_run_for_evaluation(eval_run_id) do
          {:ok, eval_run} ->
            eval_run
            |> EvalRun.fail_changeset(inspect(reason))
            |> Repo.update()
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
    eval_run
    |> EvalRun.start_changeset()
    |> Repo.update()
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

    Please evaluate the response based on the following criteria:
    1. **Accuracy**: Is the information correct and factual?
    2. **Relevance**: Does the response directly answer the user's prompt?
    3. **Completeness**: Does the response adequately address all aspects of the prompt?
    4. **Quality**: Is the response well-structured and clear?
    5. **Alignment with Expected Output**: How well does it match the expected output?

    Provide a score from 1.0 to 5.0, where 5.0 is best.
    Explain your reasoning in detail.

    Your output must be in JSON format like this:
    {"score": 4.5, "reasoning": "The response accurately addresses the user's question and provides relevant information. However, it could be more comprehensive in covering all aspects mentioned in the expected output."}
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
    case eval_run.prompt do
      nil -> AI.get_default_system_prompt()
      prompt -> prompt.content
    end
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
end
