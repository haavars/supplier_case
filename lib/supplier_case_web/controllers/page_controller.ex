defmodule SupplierCaseWeb.PageController do
  use SupplierCaseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
