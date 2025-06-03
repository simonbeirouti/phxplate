defmodule PhxplateWeb.ContactLive do
  @moduledoc """
  LiveView for the contact form page.

  This view provides a contact form that allows users (both authenticated and guests)
  to send messages to the site administrators. The form includes fields for name,
  email, subject, and message content. If a user is authenticated, their email is
  pre-filled. The form submission results in an email notification being sent.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.UserNotifier
  alias PhxplateWeb.PageMeta

  @doc """
  Renders the contact form with success message when applicable.

  Displays a form with name, email, subject, and message fields, along with
  a success message that appears briefly after successful form submission.
  """
  def render(assigns) do
    ~H"""
    <.header_section title="Contact Us" subtitle="We'd love to hear from you" />
    <div class="max-w-3xl mx-auto px-4 mb-24">
      <.simple_form for={@form} id="contact-form" phx-submit="submit">
        <div class="grid grid-cols-1 gap-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input class="text-base" field={@form[:name]} type="text" label="Name" placeholder="Your name" required />
            <.input class="text-base" field={@form[:email]} type="email" label="Email" value={@current_user_email} placeholder="your@email.com" required />
          </div>

          <.input class="text-base" field={@form[:subject]} type="text" label="Subject" placeholder="What is this regarding?" required />
          <.input class="text-base" field={@form[:message]} type="textarea" label="Message" placeholder="How can we help you?" required rows={6} />

          <input type="hidden" name="user_id" value={@current_user_id} />
        </div>

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Send Message
          </.button>
        </:actions>
      </.simple_form>
    </div>
    <.cta />
    """
  end

  @doc """
  Initializes the LiveView with the contact form and metadata.

  Sets up the form with empty fields (pre-filling email for authenticated users)
  and configures page metadata with appropriate title and description.
  """
  def mount(_params, _session, socket) do
    # Get current user if available
    current_user = socket.assigns[:current_user]
    current_user_email = if current_user, do: current_user.email, else: ""
    current_user_id = if current_user, do: current_user.id, else: nil

    socket =
      socket
      |> PageMeta.assign_metadata(
        title: "Contact Us",
        description: "Get in touch with our team",
        url: "/contact"
      )
      |> assign(:current_user_email, current_user_email)
      |> assign(:current_user_id, current_user_id)
      |> assign(:form, to_form(%{
        "name" => "",
        "email" => current_user_email,
        "subject" => "",
        "message" => ""
      }, as: "contact"))

    {:ok, socket}
  end

  @doc """
  Handles contact form submission.

  Processes the form data, sends an email notification via UserNotifier,
  resets the form, and displays a success flash message to the user.
  """
  def handle_event("submit", %{"contact" => contact_params, "user_id" => user_id}, socket) do
    user_id = if user_id == "", do: nil, else: user_id

    # Send email using UserNotifier
    UserNotifier.deliver_contact_form_email(
      contact_params["email"],
      contact_params["name"],
      contact_params["subject"],
      contact_params["message"],
      user_id
    )

    # Reset form and show success message
    socket =
      socket
      |> put_flash(:info, "Thank you for reaching out! We'll get back to you as soon as possible.")
      |> assign(:form, to_form(%{
        "name" => "",
        "email" => socket.assigns.current_user_email,
        "subject" => "",
        "message" => ""
      }, as: "contact"))

    {:noreply, socket}
  end
end
