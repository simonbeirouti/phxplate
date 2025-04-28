defmodule PhxplateWeb.ProfileHTML do
  use PhxplateWeb, :html
  import PhxplateWeb.CoreComponents

  embed_templates "profile_html/*"

  def public_index(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-8">Profiles</h1>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for profile <- @profiles do %>
          <.link href={~p"/profiles/#{profile.id}"} class="block">
            <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <.profile_avatar class="h-12 w-12 rounded-full">
                    <.profile_avatar_image src={profile.avatar_url} alt={profile.name} />
                    <.profile_avatar_fallback><%= String.slice(profile.name, 0, 2) %></.profile_avatar_fallback>
                  </.profile_avatar>
                  <div class="ml-4">
                    <h3 class="text-lg font-medium text-gray-900"><%= profile.name %></h3>
                    <p class="text-sm text-gray-500"><%= profile.title %></p>
                  </div>
                </div>
                <div class="mt-4">
                  <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600">
                    <%= profile.company_name %>
                  </span>
                </div>
              </div>
            </div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  def public_show(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6">
          <div class="flex items-center">
            <.profile_avatar class="h-16 w-16 rounded-full">
              <.profile_avatar_image src={@profile.avatar_url} alt={@profile.name} />
              <.profile_avatar_fallback><%= String.slice(@profile.name, 0, 2) %></.profile_avatar_fallback>
            </.profile_avatar>
            <div class="ml-4">
              <h1 class="text-3xl font-bold text-gray-900"><%= @profile.name %></h1>
              <p class="mt-1 text-sm text-gray-500"><%= @profile.title %> at <%= @profile.company_name %></p>
            </div>
          </div>
        </div>
        <div class="border-t border-gray-200">
          <dl>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Bio</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @profile.bio %></dd>
            </div>
            <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Skills</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <div class="flex flex-wrap gap-2">
                  <%= for skill <- @profile.skills do %>
                    <span class="inline-flex items-center rounded-md bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600">
                      <%= skill %>
                    </span>
                  <% end %>
                </div>
              </dd>
            </div>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Contact</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <.link href={"mailto:#{@profile.email}"} class="text-primary hover:text-primary/80">
                  <%= @profile.email %>
                </.link>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end
end
