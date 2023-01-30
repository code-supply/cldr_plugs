defmodule Cldr.Plug.SetLocale do
  @moduledoc false

  @deprecated "Please use Cldr.Plug.PutLocale"
  defdelegate init(options), to: Cldr.Plug.PutLocale

  defdelegate call(conn, options), to: Cldr.Plug.PutLocale
  defdelegate session_key, to: Cldr.Plug.PutLocale
  defdelegate private_key, to: Cldr.Plug.PutLocale
  defdelegate get_cldr_locale(conn), to: Cldr.Plug.PutLocale
end

defmodule Cldr.Plug.PutLocale do
  @private_key :cldr_locale
  @session_key "cldr_locale"

  @default_apps [cldr: :global]
  @default_from [:session, :accept_language, :query, :path, :route]
  @default_param_name "locale"

  @moduledoc """
  Puts the Cldr and/or Gettext locales derived from the accept-language
  header, a query parameter, a url parameter, a body parameter, the route
   or the session for the current process with `Cldr.put_locale/2` and/or
  `Gettext.put_locale/2`.

  ## Options

    * `:apps` - list of apps for which to set locale.
      See the apps configuration section.

    * `:from` - where in the request to look for the locale.
      The default is `#{inspect(@default_from)}`. The valid
      options are:
      * `:accept_language` will parse the `accept-language` header
         and finds the best matched configured locale
      * `:path` will look for a locale by examining `conn.path_params`
      * `:query` will look for a locale by examining `conn.query_params`
      * `:body` will look for a locale by examining `conn.body_params`
      * `:cookie` will look for a locale in the request cookie(s)
      * `:session` will look for a locale in the session
      * `:route` will look for a locale in the route that was
        matched under the key `private.#{inspect(@private_key)}`.
        The key may be populated by a Phoenix router and it is used
        extensively by the [ex_cldr_routes](https://hex.pm/packages/ex_cldr_routes)
        library. Note that any locale set in the route represents
        the locale defined for the route, not necessarily one requested
        by the user. Therefore setting the locale from the `:route` key
        should be a lower priority than other methods based on the actual
        request.
      * `:host` will attempt to resolve a locale from the host name top-level
        domain using `Cldr.Locale.locale_from_host/3`
      * `{Module, function, args}` in which case the indicated function will
        be called.  If it returns `{:ok, locale}` then the locale is set to
        `locale`. `locale` must be a `t:Cldr.LanguageTag.t()`.
        Any other return is considered an error and no locale will be set.
        When calling the function, `conn` and `options` will be prepended to `args`.
      * `{Module, function}` in which case the function is called with
        `conn` and `options` as its two arguments. All other behaviour is the same
        as that for a `{Module, function, args}` option.

    * `:default` - the default locale to set if no locale is
      found by other configured methods.  It can be a string like "en"
      or a `Cldr.LanguageTag` struct. It may also be `:none` to indicate
      that no locale is to be set by default. Lastly, it may also be a
      `{Module, function, args}` or `{Module, function}` tuple. The default is
      `Cldr.default_locale/1`. If the case of `{Module, function, args}`,
      a return of `{:ok, %Cldr.LanguageTag{}}` will set the locale. Any other
      return will not set a locale.

    * `:gettext` - the name of the `Gettext` backend module upon which
      the locale will be validated. This option is not required if a
      gettext module is specified in the `:apps` configuration.

    * `:cldr` - the name of the `Cldr` backend module upon which
      the locale will be validated.  This option is not required if a
      gettext module is specified in the `:apps` configuration.

    * `:session_key` - defines the key used to look for the locale
      in the session.  The default is `cldr_locale`. This option is
      deprecated and will be removed in a future release. The session
      key is being standardised in order to faciliate a simpler integration
      with [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
      by ensuring that the session key is always under a well known
      key.

  If a locale is found then `conn.private[:cldr_locale]` is also set.
  It can be retrieved with `Cldr.Plug.PutLocale.get_cldr_locale/1`.

  ## App configuration

  The `:apps` configuration key defines which applications will have
  their locale *set* by this plug.

  `Cldr.Plug.PutLocale` can set the locale for `cldr`, `gettext` or both.
  The basic configuration of the `:app` key is an atom, or list of atoms,
  containing one or both of these app names.  For example:

      apps: :cldr
      apps: :gettext
      apps: [:cldr, :gettext]

  In each of these cases, the locale is set globally
  **for the current process**.

  Sometimes setting the locale for only a specific backend is required.
  In this case, configure the `:apps` key as a keyword list pairing an
  application with the required backend module.  The value `:global` signifies
  setting the local for the global context. For example:

      apps: [cldr: MyApp.Cldr]
      apps: [gettext: MyAppGettext]
      apps: [gettext: :global]
      apps: [cldr: MyApp.Cldr, gettext: MyAppGettext]

  ## Using Cldr.Plug.PutLocale without Phoenix

  If you are using `Cldr.Plug.PutLocale` without Phoenix and you
  plan to use `:path_param` to identify the locale of a request
  then `Cldr.Plug.PutLocale` must be configured *after* `plug :match`
  and *before* `plug :dispatch`.  For example:

      defmodule MyRouter do
        use Plug.Router

        plug :match

        plug Cldr.Plug.PutLocale,
          apps: [:cldr, :gettext],
          from: [:path, :query],
          gettext: MyApp.Gettext,
          cldr: MyApp.Cldr

        plug :dispatch

        get "/hello/:locale" do
          send_resp(conn, 200, "world")
        end
      end

  ## Using Cldr.Plug.PutLocale with Phoenix

  If you are using `Cldr.Plug.PutLocale` with Phoenix and you plan
  to use the `:path_param` to identify the locale of a request then
  `Cldr.Plug.PutLocale` must be configured in the router module, *not*
  in the endpoint module. This is because `conn.path_params` has
  not yet been populated in the endpoint. For example:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug Cldr.Plug.PutLocale,
      	    apps: [:cldr, :gettext],
      	    from: [:path, :query],
      	    gettext: MyApp.Gettext,
      	    cldr: MyApp.Cldr
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end

        scope "/:locale", HelloWeb do
          pipe_through :browser

          get "/", PageController, :index
        end
      end

  ## Examples

      # Will set the global locale for the current process
      # for both `:cldr` and `:gettext`
      plug Cldr.Plug.PutLocale,
        apps:    [:cldr, :gettext],
        from:    [:query, :path, :body, :cookie, :accept_language],
        param:   "locale",
        gettext: GetTextModule,
        cldr:    MyApp.Cldr

      # Will set the backend-only locale for the current process
      # for both `:cldr` and `:gettext`
      plug Cldr.Plug.PutLocale,
        apps:    [cldr: MyApp.Cldr, gettext: GetTextModule],
        from:    [:query, :path, :body, :cookie, :accept_language],
        param:   "locale"

      # Will set the backend-only locale for the current process
      # for `:cldr` and globally for `:gettext`
      plug Cldr.Plug.PutLocale,
        apps:    [cldr: MyApp.Cldr, gettext: :global],
        from:    [:query, :path, :body, :cookie, :accept_language],
        param:   "locale"

  """

  import Plug.Conn
  require Logger
  alias Cldr.AcceptLanguage

  @from_options [
    :accept_language,
    :path,
    :body,
    :query,
    :session,
    :cookie,
    :host,
    :assigns,
    :route
  ]
  @app_options [:cldr, :gettext]

  @language_header "accept-language"

  @doc false
  def init(options) do
    options
    |> validate_apps(options[:apps])
    |> validate_from(options[:from])
    |> validate_param(options[:param])
    |> validate_cldr(options[:cldr])
    |> validate_gettext(options[:gettext])
    |> validate_default(options[:default])
    |> validate_session_key(options[:session_key])
  end

  @doc false
  def call(conn, options) do
    if locale = locale_from_params(conn, options[:from], options) || default(conn, options) do
      Enum.each(options[:apps], fn app ->
        put_locale(app, locale, options)
      end)

      put_private(conn, @private_key, locale)
    else
      conn
    end
  end

  defp default(conn, options) do
    case options[:default] do
      {module, function, args} -> get_default(conn, options, module, function, args)
      other -> other
    end
  end

  defp get_default(conn, options, module, function, args) do
    case apply(module, function, [conn, options | args]) do
      {:ok, %Cldr.LanguageTag{} = locale} -> locale
      _other -> nil
    end
  end

  @doc """
  Returns the name of the session key used
  to store the CLDR locale name.

  ## Example

    iex> Cldr.Plug.PutLocale.session_key()
    "cldr_locale"

  """
  def session_key do
    @session_key
  end

  @doc false
  def private_key do
    @private_key
  end

  @doc """
  Return the locale set by `Cldr.Plug.PutLocale`

  """
  def get_cldr_locale(conn) do
    conn.private[:cldr_locale]
  end

  defp locale_from_params(conn, from, options) do
    Enum.reduce_while(from, nil, fn param, _acc ->
      conn
      |> fetch_param(param, options[:param], options)
      |> return_if_valid_locale
    end)
  end

  defp fetch_param(conn, :accept_language, _param, options) do
    case get_req_header(conn, @language_header) do
      [accept_language] -> AcceptLanguage.best_match(accept_language, options[:cldr])
      [accept_language | _] -> AcceptLanguage.best_match(accept_language, options[:cldr])
      [] -> nil
    end
  end

  defp fetch_param(
         %Plug.Conn{query_params: %Plug.Conn.Unfetched{aspect: :query_params}} = conn,
         :query,
         param,
         options
       ) do
    conn = fetch_query_params(conn)
    fetch_param(conn, :query, param, options)
  end

  defp fetch_param(conn, :query, param, options) do
    conn
    |> Map.get(:query_params)
    |> Map.get(param)
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :path, param, options) do
    conn
    |> Map.get(:path_params)
    |> Map.get(param)
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :body, param, options) do
    conn
    |> Map.get(:body_params)
    |> Map.get(param)
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :session, _param, options) do
    conn
    |> get_session(options[:session_key])
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :cookie, param, options) do
    conn
    |> Map.get(:cookies)
    |> Map.get(param)
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :host, _param, options) do
    conn
    |> Map.get(:host)
    |> Cldr.Locale.locale_from_host(options[:cldr])
  end

  defp fetch_param(conn, :route, _param, options) do
    conn
    |> Map.fetch!(:private)
    |> Map.get(@private_key)
    |> Cldr.validate_locale(options[:cldr])
  end

  defp fetch_param(conn, :assigns, param, options) do
    fetch_param(conn, :route, param, options)
  end

  defp fetch_param(conn, {module, function, args}, _param, options) do
    apply(module, function, [conn, options | args])
  end

  defp fetch_param(conn, {module, function}, _param, options) do
    apply(module, function, [conn, options])
  end

  defp return_if_valid_locale({:ok, locale}) do
    {:halt, locale}
  end

  defp return_if_valid_locale(_) do
    {:cont, nil}
  end

  defp put_locale({:cldr, :global}, locale, _options) do
    Cldr.put_locale(locale)
  end

  # Deprecated option :all.  Use :global
  defp put_locale({:cldr, :all}, locale, _options) do
    Cldr.put_locale(locale)
  end

  defp put_locale({:cldr, backend}, locale, _options) do
    backend.put_locale(locale)
  end

  defp put_locale({:gettext, _}, %Cldr.LanguageTag{gettext_locale_name: nil} = locale, _options) do
    if is_nil(locale.backend.__cldr__(:gettext)) do
      Logger.warning(
        "The CLDR backend #{inspect(locale.backend)} has no configured Gettext backend " <>
          "under the :gettext configuration key. Gettext locale #{inspect(locale.requested_locale_name)} cannot be set."
      )
    else
      Logger.warning(
        "Locale #{inspect(locale.requested_locale_name)} does not have a known " <>
          "Gettext locale.  No Gettext locale has been set."
      )
    end

    nil
  end

  defp put_locale(
         {:gettext, :global},
         %Cldr.LanguageTag{gettext_locale_name: locale_name},
         _options
       ) do
    {:ok, apply(Gettext, :put_locale, [locale_name])}
  end

  # Deprecated option :all.  Use :global
  defp put_locale(
         {:gettext, :all},
         %Cldr.LanguageTag{gettext_locale_name: locale_name},
         _options
       ) do
    {:ok, apply(Gettext, :put_locale, [locale_name])}
  end

  defp put_locale(
         {:gettext, backend},
         %Cldr.LanguageTag{gettext_locale_name: locale_name},
         _options
       ) do
    {:ok, apply(Gettext, :put_locale, [backend, locale_name])}
  end

  defp validate_apps(options, nil), do: Keyword.put(options, :apps, @default_apps)

  defp validate_apps(options, app) when is_atom(app) do
    options
    |> Keyword.put(:apps, [app])
    |> validate_apps([app])
  end

  defp validate_apps(options, apps) when is_list(apps) do
    app_config =
      Enum.map(apps, fn
        {app, scope} ->
          validate_app_and_scope!(app, scope)
          {app, scope}

        app ->
          validate_app_and_scope!(app, nil)
          {app, :global}
      end)

    Keyword.put(options, :apps, app_config)
  end

  defp validate_apps(_options, apps) do
    raise(
      ArgumentError,
      "Invalid apps list: #{inspect(apps)}."
    )
  end

  defp validate_app_and_scope!(app, nil) when app in @app_options do
    :ok
  end

  defp validate_app_and_scope!(app, :global) when app in @app_options do
    :ok
  end

  # Deprecated option :all.  Use :global
  defp validate_app_and_scope!(app, :all) when app in @app_options do
    :ok
  end

  defp validate_app_and_scope!(:cldr, module) when is_atom(module) do
    Cldr.validate_backend!(module)
    :ok
  end

  defp validate_app_and_scope!(:gettext, module) when is_atom(module) do
    Cldr.Code.ensure_compiled?(module) ||
      raise(ArgumentError, "Gettext backend #{inspect(module)} is unknown")

    :ok
  end

  defp validate_app_and_scope!(app, scope) do
    raise(
      ArgumentError,
      "Invalid app #{inspect(app)} or scope #{inspect(scope)} detected."
    )
  end

  defp validate_from(options, nil), do: Keyword.put(options, :from, @default_from)

  defp validate_from(options, from) when is_atom(from) do
    options
    |> Keyword.put(:from, [from])
    |> validate_from([from])
  end

  defp validate_from(options, from) when is_list(from) do
    Enum.each(from, fn f ->
      if invalid_from?(f) do
        raise(
          ArgumentError,
          "Invalid :from option #{inspect(f)} detected.  " <>
            " Valid :from options are #{inspect(@from_options)}"
        )
      end
    end)

    options
  end

  defp validate_from(_options, from) do
    raise(
      ArgumentError,
      "Invalid :from list #{inspect(from)} detected.  " <>
        "Valid from options are #{inspect(@from_options)}"
    )
  end

  defp invalid_from?(:assigns) do
    IO.warn("The :from option `:assigns` is deprecated and should be replaced with `:route`", [])
    false
  end

  defp invalid_from?(from) when from in @from_options do
    false
  end

  defp invalid_from?({module, function, args})
       when is_atom(module) and is_atom(function) and is_list(args) do
    false
  end

  defp invalid_from?({module, function})
       when is_atom(module) and is_atom(function) do
    false
  end

  defp invalid_from?(_other) do
    true
  end

  defp validate_param(options, nil), do: Keyword.put(options, :param, @default_param_name)
  defp validate_param(options, param) when is_binary(param), do: options

  defp validate_param(options, param) when is_atom(param) do
    validate_from(options, param)
  end

  defp validate_param(_options, param) do
    raise(
      ArgumentError,
      "Invalid :param #{inspect(param)} detected. " <> ":param must be a string"
    )
  end

  defp validate_default(options, nil) do
    default = options[:cldr].default_locale()
    Keyword.put(options, :default, default)
  end

  defp validate_default(options, :none) do
    Keyword.put(options, :default, nil)
  end

  defp validate_default(options, {module, function, args})
       when is_atom(module) and is_atom(function) and is_list(args) do
    Keyword.put(options, :default, {module, function, args})
  end

  defp validate_default(options, {module, function})
       when is_atom(module) and is_atom(function) do
    Keyword.put(options, :default, {module, function, []})
  end

  defp validate_default(options, default) do
    case Cldr.validate_locale(default, options[:cldr]) do
      {:ok, locale} -> Keyword.put(options, :default, locale)
      {:error, {exception, reason}} -> raise exception, reason
    end
  end

  # No configured gettext.  See if there is one configured
  # on the Cldr backend
  defp validate_gettext(options, nil) do
    gettext = options[:cldr].__cldr__(:config).gettext

    if gettext && get_in(options, [:apps, :gettext]) do
      Keyword.put(options, :gettext, gettext)
    else
      options
    end
  end

  defp validate_gettext(options, gettext) do
    case Code.ensure_compiled(gettext) do
      {:error, _} ->
        raise ArgumentError, "Gettext module #{inspect(gettext)} is not known"

      {:module, _} ->
        options
    end
  end

  defp validate_session_key(options, nil),
    do: Keyword.put(options, :session_key, @session_key)

  defp validate_session_key(options, session_key) when is_binary(session_key) do
    IO.warn(
      "The :session_key option is deprecated and will be removed in " <>
        "a future release. The session key is being standardised as #{inspect(@session_key)}",
      []
    )

    options
  end

  defp validate_session_key(_options, session_key) do
    raise(
      ArgumentError,
      "Invalid :session_key #{inspect(session_key)} detected. " <>
        ":session_key must be a string"
    )
  end

  defp validate_cldr(options, nil) do
    backend = Keyword.get_lazy(options[:apps], :cldr, &Cldr.default_locale/0)
    validate_cldr(options, backend)
  end

  defp validate_cldr(options, backend) when is_atom(backend) do
    with {:ok, backend} <- Cldr.validate_backend(backend) do
      Keyword.put(options, :cldr, backend)
    else
      {:error, {exception, reason}} -> raise exception, reason
    end
  end
end
