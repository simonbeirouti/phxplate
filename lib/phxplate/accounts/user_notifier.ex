defmodule Phxplate.Accounts.UserNotifier do
  use PhxplateWeb, :html
  import Swoosh.Email
  require Logger

  alias Phxplate.Mailer

  # Common email CSS styles
  defp email_styles do
    """
    /* Base styles for all email clients */
    body {
      font-family: sans-serif;
      line-height: 1.6;
      color: #0a0b0e; /* --foreground: 224 71.4% 4.1% */
      background-color: #f8f9fc; /* --secondary: 220 14.3% 95.9% */
      margin: 0;
      padding: 0;
    }
    .container {
      width: 100%;
      max-width: 600px;
      margin: 0 auto;
      background-color: #ffffff; /* --background: 0 0% 100% */
      border-radius: 1rem; /* --radius: 1rem */
      border: 1px solid #e6e8ec; /* --border: 220 13% 91% */
    }
    .header {
      text-align: center;
      padding: 20px 0;
      border-bottom: 1px solid #e6e8ec; /* --border: 220 13% 91% */
    }
    .content {
      padding: 20px;
    }
    .footer {
      text-align: center;
      color: #717789; /* --muted-foreground: 220 8.9% 46.1% */
      font-size: 14px;
      padding: 20px 0;
      border-top: 1px solid #e6e8ec; /* --border: 220 13% 91% */
    }
    .button {
      display: inline-block;
      padding: 10px 20px;
      margin: 20px 0;
      background-color: #141c2e; /* --primary: 220.9 39.3% 11% */
      color: #f5f7fe !important; /* --primary-foreground: 210 20% 98% */
      text-decoration: none;
      border-radius: 0.5rem;
      font-weight: bold;
    }
    .message-box {
      margin: 20px 0;
      padding: 15px;
      border: 1px solid #e6e8ec; /* --border: 220 13% 91% */
      border-radius: 0.5rem;
      background-color: #f8f9fc; /* --secondary: 220 14.3% 95.9% */
    }
    h1, h2, h3 {
      color: #0a0b0e; /* --foreground: 224 71.4% 4.1% */
    }
    a {
      color: #141c2e; /* --primary: 220.9 39.3% 11% */
      text-decoration: underline;
    }
    """
  end

  # Email layout template with content injection
  defp email_layout(title, content, app_name, year, recipient_email) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width">
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
      <title>#{title}</title>
      <style>
        #{email_styles()}
      </style>
    </head>
    <body>
      <table width="100%" border="0" cellspacing="0" cellpadding="0">
        <tr>
          <td align="center" style="padding: 20px 0;">
            <div class="container">
              <div class="header">
                <h2>#{app_name}</h2>
              </div>
              <div class="content">
                #{content}
              </div>
              <div class="footer">
                <p>&copy; #{year} #{app_name}</p>
                <p><small>This email was sent to #{recipient_email}</small></p>
              </div>
            </div>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  # Helper function to render an email template with assigns
  defp render_email_template(template_assigns) do
    assigns = template_assigns
    app_name = assigns[:app_name]
    year = assigns[:year]

    content = case assigns[:template] do
      "confirmation_instructions" ->
        """
        <h2>Hi #{assigns.user.email},</h2>
        <p>You can confirm your account by clicking the button below:</p>
        <div style="text-align: center;">
          <a href="#{assigns.url}" class="button">Confirm Account</a>
        </div>
        <p>If you're having trouble with the button above, copy and paste the URL below into your web browser:</p>
        <p><a href="#{assigns.url}">#{assigns.url}</a></p>
        <p>If you didn't create an account with us, please ignore this email.</p>
        """

      "reset_password_instructions" ->
        """
        <h1>Hi #{assigns.user.email},</h1>
        <p>You can reset your password by clicking the button below:</p>
        <div style="text-align: center;">
          <a href="#{assigns.url}" class="button">Reset Password</a>
        </div>
        <p>If you're having trouble with the button above, copy and paste the URL below into your web browser:</p>
        <p><a href="#{assigns.url}">#{assigns.url}</a></p>
        <p>If you didn't request this change, please ignore this email.</p>
        """

      "update_email_instructions" ->
        """
        <h1>Hi #{assigns.user.email},</h1>
        <p>You can change your email by clicking the button below:</p>
        <div style="text-align: center;">
          <a href="#{assigns.url}" class="button">Update Email</a>
        </div>
        <p>If you're having trouble with the button above, copy and paste the URL below into your web browser:</p>
        <p><a href="#{assigns.url}">#{assigns.url}</a></p>
        <p>If you didn't request this change, please ignore this email.</p>
        """

      "company_invitation" ->
        """
        <h1>Hello,</h1>
        <p>You have been invited to join <strong>#{assigns.company.name}</strong> on #{app_name}.</p>
        <div style="text-align: center;">
          <a href="#{assigns.invitation_url}" class="button">Accept Invitation</a>
        </div>
        <p>If you're having trouble with the button above, copy and paste the URL below into your web browser:</p>
        <p><a href="#{assigns.invitation_url}">#{assigns.invitation_url}</a></p>
        <p>If you weren't expecting this invitation, you can safely ignore this email.</p>
        """

      "contact_form_email" ->
        user_id_info = if assigns[:user_id] do
          "<p><strong>Submitted by registered user ID:</strong> #{assigns.user_id}</p>"
        else
          "<p><strong>Submitted by:</strong> Unregistered visitor</p>"
        end

        """
        <h1>New Contact Form Submission</h1>
        <div class="message-box">
          <p><strong>From:</strong> #{assigns.name} (#{assigns.email})</p>
          <p><strong>Subject:</strong> #{assigns.subject}</p>
          #{user_id_info}
        </div>

        <h3>Message:</h3>
        <div class="message-box">
          <p>#{assigns.message}</p>
        </div>
        """

      "contact_form_confirmation" ->
        """
        <h1>Thank you for contacting us</h1>
        <p>Hi #{assigns.name},</p>
        <p>Thank you for reaching out to us. This is a confirmation that we have received your message:</p>

        <div class="message-box">
          <p><strong>Subject:</strong> #{assigns.subject}</p>
        </div>

        <p>Our team will review your message and get back to you as soon as possible.</p>
        <p>Thanks for your patience!</p>
        """
    end

    # Determine email title and recipient
    title = case assigns[:template] do
      "confirmation_instructions" -> "Confirmation instructions"
      "reset_password_instructions" -> "Reset password instructions"
      "update_email_instructions" -> "Update email instructions"
      "company_invitation" -> "Invitation to join #{assigns.company.name}"
      "contact_form_email" -> "Contact Form: #{assigns.subject}"
      "contact_form_confirmation" -> "Thank you for contacting us"
    end

    recipient_email = cond do
      Map.has_key?(assigns, :recipient_email) -> assigns.recipient_email
      Map.has_key?(assigns, :user) -> assigns.user.email
      Map.has_key?(assigns, :email) -> assigns.email
      true -> "recipient"
    end

    email_layout(title, content, app_name, year, recipient_email)
  end

  # Direct template rendering approach
  def deliver_confirmation_instructions(user, url) do
    template_assigns = %{
      template: "confirmation_instructions",
      user: user,
      url: url,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year
    }

    text_body = """
    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """

    deliver(user.email, "Confirmation instructions", text_body, render_email_template(template_assigns))
  end

  def deliver_reset_password_instructions(user, url) do
    template_assigns = %{
      template: "reset_password_instructions",
      user: user,
      url: url,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year
    }

    text_body = """
    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    deliver(user.email, "Reset password instructions", text_body, render_email_template(template_assigns))
  end

  def deliver_update_email_instructions(user, url) do
    template_assigns = %{
      template: "update_email_instructions",
      user: user,
      url: url,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year
    }

    text_body = """
    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """

    deliver(user.email, "Update email instructions", text_body, render_email_template(template_assigns))
  end

  def deliver_company_invitation(email, company, invitation_url) do
    template_assigns = %{
      template: "company_invitation",
      company: company,
      invitation_url: invitation_url,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year,
      recipient_email: email
    }

    text_body = """
    ==============================

    Hi,

    You have been invited to join #{company.name} on #{Phxplate.config([:title])}.

    You can accept this invitation by visiting the URL below:

    #{invitation_url}

    If you weren't expecting this invitation, you can safely ignore this email.

    ==============================
    """

    deliver(email, "Invitation to join #{company.name}", text_body, render_email_template(template_assigns))
  end

  @doc """
  Deliver contact form submission email.

  Sends the contents of the contact form to the admin email address
  and includes information about the sender.
  """
  def deliver_contact_form_email(email, name, subject, message, user_id) do
    admin_email = "admin@example.com" # Replace with actual admin email

    # Email to admin
    admin_template_assigns = %{
      template: "contact_form_email",
      name: name,
      email: email,
      subject: subject,
      message: message,
      user_id: user_id,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year,
      recipient_email: admin_email
    }

    admin_text_body = """
    ==============================

    New contact form submission:

    From: #{name} (#{email})
    Subject: #{subject}
    #{if user_id, do: "\nSubmitted by registered user ID: #{user_id}", else: "\nSubmitted by unregistered visitor"}

    Message:
    #{message}

    ==============================
    """

    admin_subject = "Contact Form: #{subject}"
    deliver(admin_email, admin_subject, admin_text_body, render_email_template(admin_template_assigns))

    # Confirmation email to user
    user_template_assigns = %{
      template: "contact_form_confirmation",
      name: name,
      subject: subject,
      app_name: Phxplate.config([:title]),
      year: DateTime.utc_now().year,
      recipient_email: email
    }

    user_text_body = """
    ==============================

    Hi #{name},

    Thank you for contacting us. This is a confirmation that we have received your message:

    Subject: #{subject}

    Our team will review your message and get back to you as soon as possible.

    ==============================
    """

    user_subject = "Thank you for contacting us"
    deliver(email, user_subject, user_text_body, render_email_template(user_template_assigns))
  end

  # Delivers the email using the application mailer with HTML support
  defp deliver(recipient, subject, text_body, html_body) do
    email =
      new()
      |> to(recipient)
      |> from({Phxplate.config([:title]), Phxplate.config([:email])})
      |> subject(subject)
      |> text_body(text_body)

    email =
      if html_body do
        # Process HTML with Premailex to inline CSS for better email client compatibility
        processed_html = Premailex.to_inline_css(html_body)

        email |> html_body(processed_html)
      else
        email
      end

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        {:ok, email}
      {:error, reason} ->
        Logger.warning("Sending email failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
