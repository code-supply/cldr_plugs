defmodule Cldr.Plug.PutLocale.Test do
  use ExUnit.Case, async: true
  use Plug.Test

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  import Plug.Conn,
    only: [
      put_req_header: 3,
      put_session: 3,
      fetch_session: 2,
      put_resp_cookie: 3,
      fetch_cookies: 1
    ]

  test "init returns the default options" do
    opts = Cldr.Plug.PutLocale.init(cldr: TestBackend.Cldr)

    assert opts == [
             session_key: "cldr_locale",
             default: %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "en-001",
               cldr_locale_name: :"en-001",
               extensions: %{},
               gettext_locale_name: "en",
               language: "en",
               language_subtags: [],
               language_variants: [],
               locale: %{},
               private_use: [],
               rbnf_locale_name: :en,
               requested_locale_name: "en-001",
               script: :Latn,
               territory: :"001",
               transform: %{}
             },
             cldr: TestBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global]
           ]
  end

  test "init sets the gettext locale if not is defined, and its in :apps and cldr has one" do
    opts = Cldr.Plug.PutLocale.init(apps: [:cldr, :gettext], cldr: TestBackend.Cldr)

    assert opts == [
             session_key: "cldr_locale",
             default: %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "en-001",
               cldr_locale_name: :"en-001",
               extensions: %{},
               gettext_locale_name: "en",
               language: "en",
               language_subtags: [],
               language_variants: [],
               locale: %{},
               private_use: [],
               rbnf_locale_name: :en,
               requested_locale_name: "en-001",
               script: :Latn,
               territory: :"001",
               transform: %{}
             },
             gettext: TestGettext.Gettext,
             cldr: TestBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global, gettext: :global]
           ]
  end

  test "init allows an MFA as the default locale" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [:cldr, :gettext],
        cldr: TestBackend.Cldr,
        default: {Mymodule, :my_function}
      )

    assert opts == [
             session_key: "cldr_locale",
             default: {Mymodule, :my_function, []},
             gettext: TestGettext.Gettext,
             cldr: TestBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global, gettext: :global]
           ]

    opts =
      Cldr.Plug.PutLocale.init(
        apps: [:cldr, :gettext],
        cldr: TestBackend.Cldr,
        default: {Mymodule, :my_function, [:arg1]}
      )

    assert opts == [
             session_key: "cldr_locale",
             default: {Mymodule, :my_function, [:arg1]},
             gettext: TestGettext.Gettext,
             cldr: TestBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global, gettext: :global]
           ]
  end

  test "init allows a default configured as :none" do
    opts =
      Cldr.Plug.PutLocale.init(apps: [:cldr, :gettext], cldr: TestBackend.Cldr, default: :none)

    assert opts == [
             session_key: "cldr_locale",
             default: nil,
             gettext: TestGettext.Gettext,
             cldr: TestBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global, gettext: :global]
           ]
  end

  test "init allows MFA as a :from option" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [:cldr, :gettext],
        cldr: TestBackend.Cldr,
        from: [:path, {Mymodule, :my_function, [:arg1]}, :query, {MyModule, :myfunction}],
        default: :none
      )

    assert opts == [
             session_key: "cldr_locale",
             default: nil,
             gettext: TestGettext.Gettext,
             cldr: TestBackend.Cldr,
             param: "locale",
             apps: [cldr: :global, gettext: :global],
             from: [:path, {Mymodule, :my_function, [:arg1]}, :query, {MyModule, :myfunction}]
           ]
  end

  # On older versions of elixir, the capture_io call raises
  # an exception.
  test "session key deprecation is emitted" do
    try do
      assert capture_io(:stderr, fn ->
               Cldr.Plug.PutLocale.init(session_key: "key", cldr: WithNoGettextBackend.Cldr)
             end) =~
               "The :session_key option is deprecated and will be removed in a future release"
    rescue
      RuntimeError ->
        true
    end
  end

  test "init does not set the gettext locale if not defined, and its in :apps and cldr does not have one" do
    opts = Cldr.Plug.PutLocale.init(apps: [:cldr, :gettext], cldr: WithNoGettextBackend.Cldr)

    assert opts == [
             session_key: "cldr_locale",
             default: %Cldr.LanguageTag{
               backend: WithNoGettextBackend.Cldr,
               canonical_locale_name: "en-001",
               cldr_locale_name: :"en-001",
               extensions: %{},
               gettext_locale_name: nil,
               language: "en",
               language_subtags: [],
               language_variants: [],
               locale: %{},
               private_use: [],
               rbnf_locale_name: :en,
               requested_locale_name: "en-001",
               script: :Latn,
               territory: :"001",
               transform: %{}
             },
             cldr: WithNoGettextBackend.Cldr,
             param: "locale",
             from: [:session, :accept_language, :query, :path, :route],
             apps: [cldr: :global, gettext: :global]
           ]
  end

  test "Warning is logged with setting Gettext locale and there is no CLDR gettext module set" do
    opts =
      Cldr.Plug.PutLocale.init(
        from: :query,
        cldr: WithNoGettextBackend.Cldr,
        apps: [cldr: :global, gettext: :global]
      )

    assert capture_log(fn ->
             :get
             |> conn("/?locale=fr")
             |> Cldr.Plug.PutLocale.call(opts)
           end) =~
             ~r/The CLDR backend WithNoGettextBackend.Cldr has no configured Gettext backend under the :gettext configuration key./
  end

  test "Warning is logged with setting Gettext locale that does not exist" do
    opts =
      Cldr.Plug.PutLocale.init(
        from: :query,
        cldr: TestBackend.Cldr,
        apps: [cldr: :global, gettext: :global]
      )

    assert capture_log(fn ->
             :get
             |> conn("/?locale=fr")
             |> Cldr.Plug.PutLocale.call(opts)
           end) =~
             ~r/Locale .* does not have a known Gettext locale.  No Gettext locale has been set./
  end

  test "bad parameters raise exceptions" do
    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(from: :nothing, cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(from: :nothing, cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(from: [:nothing], cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(apps: :nothing, cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(apps: [:nothing], cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(param: [:nothing], cldr: TestBackend.Cldr)
    end

    assert_raise ArgumentError, fn ->
      Cldr.Plug.PutLocale.init(gettext: BlatherBalls, cldr: TestBackend.Cldr)
    end

    assert_raise Cldr.InvalidLanguageError, fn ->
      Cldr.Plug.PutLocale.init(default: :nothing, cldr: TestBackend.Cldr)
    end
  end

  test "set the locale from a query param" do
    opts = Cldr.Plug.PutLocale.init(from: :query, cldr: TestBackend.Cldr)

    conn =
      :get
      |> conn("/?locale=fr")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "fr",
               cldr_locale_name: :fr,
               extensions: %{},
               gettext_locale_name: nil,
               language: "fr",
               locale: %{},
               private_use: [],
               rbnf_locale_name: :fr,
               requested_locale_name: "fr",
               script: :Latn,
               territory: :FR,
               transform: %{},
               language_variants: []
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "set the locale from the host" do
    opts = Cldr.Plug.PutLocale.init(from: :host, cldr: TestBackend.Cldr)

    capture_log(fn ->
      conn =
        :get
        |> conn("/")
        |> Map.put(:host, "www.site.fr")
        |> Cldr.Plug.PutLocale.call(opts)

      assert conn.private[:cldr_locale] ==
               %Cldr.LanguageTag{
                 backend: TestBackend.Cldr,
                 canonical_locale_name: "fr-FR",
                 cldr_locale_name: :fr,
                 extensions: %{},
                 gettext_locale_name: nil,
                 language: "fr",
                 locale: %{},
                 private_use: [],
                 rbnf_locale_name: :fr,
                 requested_locale_name: "fr-FR",
                 script: :Latn,
                 territory: :FR,
                 transform: %{},
                 language_variants: []
               }

      assert Cldr.get_locale() == conn.private[:cldr_locale]
    end)
  end

  test "set the locale from assigns" do
    opts = Cldr.Plug.PutLocale.init(from: :route, cldr: TestBackend.Cldr)

    capture_log(fn ->
      conn =
        :get
        |> conn("/hello")
        |> MyRouter.call(opts)

      assert conn.private[:cldr_locale] ==
               %Cldr.LanguageTag{
                 backend: TestBackend.Cldr,
                 canonical_locale_name: "fr-FR",
                 cldr_locale_name: :fr,
                 extensions: %{},
                 gettext_locale_name: nil,
                 language: "fr",
                 locale: %{},
                 private_use: [],
                 rbnf_locale_name: :fr,
                 requested_locale_name: "fr-FR",
                 script: :Latn,
                 territory: :FR,
                 transform: %{},
                 language_variants: []
               }

      assert Cldr.get_locale() == conn.private[:cldr_locale]
    end)
  end

  test "set the locale from the session using a locale name" do
    opts = Cldr.Plug.PutLocale.init(from: :session, cldr: TestBackend.Cldr)
    session_opts = Plug.Session.init(store: :cookie, key: "_key", signing_salt: "X")

    conn =
      :get
      |> conn("/")
      |> Plug.Session.call(session_opts)
      |> fetch_session("cldr_locale")
      |> put_session("cldr_locale", "ru")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               extensions: %{},
               gettext_locale_name: nil,
               locale: %{},
               private_use: [],
               transform: %{},
               language_variants: [],
               canonical_locale_name: "ru",
               cldr_locale_name: :ru,
               language: "ru",
               rbnf_locale_name: :ru,
               requested_locale_name: "ru",
               script: :Cyrl,
               territory: :RU
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "set the locale from a body param" do
    opts = Cldr.Plug.PutLocale.init(from: :body, cldr: TestBackend.Cldr)
    parser_opts = Plug.Parsers.init(parsers: [:json], json_decoder: Jason)
    json = %{locale: "zh-Hant"}

    conn =
      :put
      |> conn("/?locale=fr", json)
      |> Plug.Parsers.call(parser_opts)
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               extensions: %{},
               gettext_locale_name: nil,
               locale: %{},
               private_use: [],
               transform: %{},
               language_variants: [],
               canonical_locale_name: "zh-Hant",
               cldr_locale_name: :"zh-Hant",
               language: "zh",
               rbnf_locale_name: :"zh-Hant",
               requested_locale_name: "zh-Hant",
               script: :Hant,
               territory: :TW
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "set the locale from a cookie param" do
    opts = Cldr.Plug.PutLocale.init(from: :cookie, cldr: TestBackend.Cldr)

    conn =
      :get
      |> conn("/?locale=fr")
      |> fetch_cookies()
      |> put_resp_cookie("locale", "zh-Hant")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               extensions: %{},
               gettext_locale_name: nil,
               locale: %{},
               private_use: [],
               transform: %{},
               language_variants: [],
               canonical_locale_name: "zh-Hant",
               cldr_locale_name: :"zh-Hant",
               language: "zh",
               rbnf_locale_name: :"zh-Hant",
               requested_locale_name: "zh-Hant",
               script: :Hant,
               territory: :TW
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "that a gettext locale is set as an ancestor if it exists" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [cldr: MyApp.Cldr, gettext: MyApp.Gettext],
        from: [:accept_language],
        param: "locale",
        default: "en-GB"
      )

    conn =
      :get
      |> conn("/")
      |> put_req_header("accept-language", "en-AU")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale].gettext_locale_name == "en"
  end

  test "set the locale from an MF" do
    opts = Cldr.Plug.PutLocale.init(cldr: TestBackend.Cldr, from: [{MyModule, :get_locale}])

    conn =
      :get
      |> conn("/")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "fr",
               cldr_locale_name: :fr,
               extensions: %{},
               gettext_locale_name: nil,
               language: "fr",
               locale: %{},
               private_use: [],
               rbnf_locale_name: :fr,
               requested_locale_name: "fr",
               script: :Latn,
               territory: :FR,
               transform: %{},
               language_variants: []
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "set the locale from an MFA" do
    opts =
      Cldr.Plug.PutLocale.init(cldr: TestBackend.Cldr, from: [{MyModule, :get_locale, [:fred]}])

    conn =
      :get
      |> conn("/")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "fr",
               cldr_locale_name: :fr,
               extensions: %{},
               gettext_locale_name: nil,
               language: "fr",
               locale: %{},
               private_use: [],
               rbnf_locale_name: :fr,
               requested_locale_name: "fr",
               script: :Latn,
               territory: :FR,
               transform: %{},
               language_variants: []
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "that a gettext locale is set on the global gettext context" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [cldr: MyApp.Cldr, gettext: :all],
        from: [:accept_language],
        param: "locale",
        default: "en-GB"
      )

    conn =
      :get
      |> conn("/")
      |> put_req_header("accept-language", "es")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale].gettext_locale_name == "es"
    assert Gettext.get_locale() == "es"
  end

  test "locale is set according to the configured priority" do
    opts = Cldr.Plug.PutLocale.init(from: [:accept_language, :query], cldr: TestBackend.Cldr)

    conn =
      :get
      |> conn("/?locale=fr")
      |> put_req_header("accept-language", "pl")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               canonical_locale_name: "pl",
               cldr_locale_name: :pl,
               extensions: %{},
               gettext_locale_name: nil,
               language: "pl",
               locale: %{},
               private_use: [],
               rbnf_locale_name: :pl,
               requested_locale_name: "pl",
               script: :Latn,
               territory: :PL,
               transform: %{},
               language_variants: []
             }

    assert Cldr.get_locale() == conn.private[:cldr_locale]
  end

  test "gettext locale is set" do
    opts =
      Cldr.Plug.PutLocale.init(
        from: [:query],
        cldr: TestBackend.Cldr,
        gettext: TestGettext.Gettext,
        apps: :gettext
      )

    conn =
      :get
      |> conn("/?locale=es")
      |> Cldr.Plug.PutLocale.call(opts)

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               extensions: %{},
               gettext_locale_name: "es",
               language_subtags: [],
               language_variants: [],
               locale: %{},
               private_use: [],
               script: :Latn,
               transform: %{},
               canonical_locale_name: "es",
               cldr_locale_name: :es,
               language: "es",
               rbnf_locale_name: :es,
               requested_locale_name: "es",
               territory: :ES
             }

    assert Gettext.get_locale(TestGettext.Gettext) == "es"
  end

  test "another gettext example" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [:cldr, :gettext],
        from: [:query, :path, :cookie, :accept_language],
        cldr: TestBackend.Cldr,
        param: "locale",
        gettext: TestGettext.Gettext
      )

    :get
    |> conn("/?locale=es")
    |> Cldr.Plug.PutLocale.call(opts)

    assert Gettext.get_locale(TestGettext.Gettext) == "es"
  end

  test "config with no gettext" do
    opts =
      Cldr.Plug.PutLocale.init(
        apps: [:cldr, :gettext],
        from: [:query, :path, :cookie, :accept_language],
        cldr: TestBackend.Cldr,
        param: "locale"
      )

    :get
    |> conn("/?locale=es")
    |> Cldr.Plug.PutLocale.call(opts)

    assert Gettext.get_locale(TestGettext.Gettext) == "es"
  end

  test "locale detection from path params with parser plug" do
    conn = conn(:get, "/hello/es", %{this: "thing"})
    conn = MyRouter.call(conn, MyRouter.init([]))

    assert conn.private[:cldr_locale] ==
             %Cldr.LanguageTag{
               backend: TestBackend.Cldr,
               extensions: %{},
               gettext_locale_name: "es",
               language_subtags: [],
               language_variants: [],
               locale: %{},
               private_use: [],
               script: :Latn,
               transform: %{},
               canonical_locale_name: "es",
               cldr_locale_name: :es,
               language: "es",
               rbnf_locale_name: :es,
               requested_locale_name: "es",
               territory: :ES
             }

    assert Gettext.get_locale(TestGettext.Gettext) == "es"
  end
end
