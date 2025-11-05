defmodule RiceMillWeb.PageController do
  use RiceMillWeb, :controller

  def home(conn, _params) do
    # Redirect authenticated users to their appropriate dashboard
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      user = conn.assigns.current_scope.user

      redirect_path =
        case user.role do
          :super_admin -> ~p"/admin/dashboard"
          :company_admin -> ~p"/products"
          :operator -> ~p"/products"
          :viewer -> ~p"/products"
          _ -> ~p"/"
        end

      redirect(conn, to: redirect_path)
    else
      render(conn, :home)
    end
  end
end
