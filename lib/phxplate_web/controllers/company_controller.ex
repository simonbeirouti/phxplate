defmodule PhxplateWeb.CompanyController do
  use PhxplateWeb, :controller
  alias Phxplate.Companies

  def public_index(conn, _params) do
    companies = Companies.list_companies()
    render(conn, :public_index, companies: companies)
  end

  def public_show(conn, %{"id" => id}) do
    case Companies.get_company(id) do
      nil ->
        conn
        |> put_flash(:error, "Company not found")
        |> redirect(to: ~p"/companies")
      company ->
        render(conn, :public_show, company: company)
    end
  end
end
