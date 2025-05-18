defmodule PhxplateWeb.ContactLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.UserNotifier
  alias PhxplateWeb.PageMeta

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4">Contact Us</h1>
        <p class="text-lg text-gray-600">We'd love to hear from you. Fill out the form below to get in touch with our team.</p>
      </div>

      <.simple_form for={@form} id="contact-form" phx-submit="submit">
        <div class="grid grid-cols-1 gap-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input field={@form[:name]} type="text" label="Name" placeholder="Your name" required />
            <.input field={@form[:email]} type="email" label="Email" value={@current_user_email} placeholder="your@email.com" required />
          </div>

          <.input field={@form[:subject]} type="text" label="Subject" placeholder="What is this regarding?" required />
          <.input field={@form[:message]} type="textarea" label="Message" placeholder="How can we help you?" required rows={6} />

          <input type="hidden" name="user_id" value={@current_user_id} />
        </div>

        <:actions>
          <.button phx-disable-with="Sending..." class="w-full md:w-auto">
            Send Message
          </.button>
        </:actions>
      </.simple_form>

      <div :if={@show_success} class="mt-8 p-4 bg-green-50 rounded-md border border-green-200">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-green-800">Message sent successfully</h3>
            <div class="mt-2 text-sm text-green-700">
              <p>Thank you for reaching out! We'll get back to you as soon as possible.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

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
      |> assign(:show_success, false)
      |> assign(:current_user_email, current_user_email)
      |> assign(:current_user_id, current_user_id)
      |> assign(:form, to_form(%{
        name: "",
        email: current_user_email,
        subject: "",
        message: ""
      }, as: "contact"))

    {:ok, socket}
  end

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
      |> assign(:show_success, true)
      |> assign(:form, to_form(%{
        name: "",
        email: socket.assigns.current_user_email,
        subject: "",
        message: ""
      }, as: "contact"))

    # Hide success message after 5 seconds
    Process.send_after(self(), :hide_success, 5000)

    {:noreply, socket}
  end

  def handle_info(:hide_success, socket) do
    {:noreply, assign(socket, :show_success, false)}
  end
end
