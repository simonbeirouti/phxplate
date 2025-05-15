defmodule Phxplate.Policy do
  use LetMe.Policy

  object :company do
    action :view do
      allow role: :basic
      allow role: :admin
      allow role: :super_admin
      desc "View company information"
    end

    action :create do
      allow role: :admin
      allow role: :super_admin
      desc "Create new company"
    end

    action :edit do
      allow role: :super_admin
      desc "Edit company information"
    end

    action :delete do
      allow role: :super_admin
      desc "Delete company"
    end
  end

  object :employee do
    action :view do
      allow role: :basic
      allow role: :admin
      allow role: :super_admin
      desc "View employee information"
    end

    action :create do
      allow role: :admin
      allow role: :super_admin
      desc "Create new employee"
    end

    action :edit do
      allow role: :super_admin
      desc "Edit employee information"
    end

    action :delete do
      allow role: :super_admin
      desc "Delete employee"
    end
  end

  object :subscription do
    # Company subscriptions
    action :company_updates do
      allow [:own_company, role: :admin]
      allow role: :super_admin
      desc "Subscribe to company updates"
    end

    # Employee subscriptions
    action :employee_updates do
      allow [:own_company, role: :admin]
      allow role: :super_admin
      desc "Subscribe to employee updates"
    end

    # Bookmark subscriptions
    action :bookmark_updates do
      allow [:own_resource, role: :basic]
      allow role: :admin
      allow role: :super_admin
      desc "Subscribe to bookmark updates"
    end

    # Invitation subscriptions
    action :invitation_updates do
      allow [:own_resource, role: :basic]
      allow role: :admin
      allow role: :super_admin
      desc "Subscribe to invitation updates"
    end

    # Global company subscriptions (for admins and super admins)
    action :all_companies do
      allow role: :admin
      allow role: :super_admin
      desc "Subscribe to all company updates"
    end

    # Global employee subscriptions (for admins and super admins)
    action :all_employees do
      allow role: :admin
      allow role: :super_admin
      desc "Subscribe to all employee updates"
    end
  end
end
