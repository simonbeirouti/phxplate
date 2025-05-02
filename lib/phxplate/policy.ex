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
end
