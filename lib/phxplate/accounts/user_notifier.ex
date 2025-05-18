defmodule Phxplate.Accounts.UserNotifier do
  import Swoosh.Email

  alias Phxplate.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({Phxplate.config([:title]), Phxplate.config([:email])})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver company invitation email.
  """
  def deliver_company_invitation(email, company, invitation_url) do
    deliver(email, "Invitation to join #{company.name}", """

    ==============================

    Hi,

    You have been invited to join #{company.name} on Phxplate.

    You can accept this invitation by visiting the URL below:

    #{invitation_url}

    If you weren't expecting this invitation, you can safely ignore this email.

    ==============================
    """)
  end

  @doc """
  Deliver contact form submission email.

  Sends the contents of the contact form to the admin email address
  and includes information about the sender.
  """
  def deliver_contact_form_email(email, name, subject, message, user_id) do
    admin_email = "admin@example.com" # Replace with actual admin email

    user_info = if user_id, do: "\nSubmitted by registered user ID: #{user_id}", else: "\nSubmitted by unregistered visitor"

    deliver(admin_email, "Contact Form: #{subject}", """
    ==============================

    New contact form submission:

    From: #{name} (#{email})#{user_info}
    Subject: #{subject}

    Message:
    #{message}

    ==============================
    """)

    # Also send a confirmation to the user
    deliver(email, "Thank you for contacting us", """
    ==============================

    Hi #{name},

    Thank you for contacting us. This is a confirmation that we have received your message:

    Subject: #{subject}

    Our team will review your message and get back to you as soon as possible.

    ==============================
    """)
  end
end
