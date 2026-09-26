require 'sinatra'
require 'sqlite3'
require 'securerandom'
require 'time'

# ============================================================
# Configurare Sinatra / Render
# ============================================================

set :port, ENV.fetch('PORT', 4567)
set :bind, '0.0.0.0'

# ============================================================
# Baza de date SQLite
#
# Local:
#   snippets.db
#
# Render:
#   /var/data/snippets.db
# ============================================================

db_path = ENV.fetch('DATABASE_PATH', 'snippets.db')

DB = SQLite3::Database.new(db_path)
DB.results_as_hash = true

# ============================================================
# Creare tabel
# ============================================================

DB.execute <<-SQL
  CREATE TABLE IF NOT EXISTS snippets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME NOT NULL,
    expires_at DATETIME
  );
SQL

# ============================================================
# Helpers
# ============================================================

helpers do
  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end
end

# ============================================================
# Pagina principală
# ============================================================

get '/' do
  erb :index
end

# ============================================================
# Creare snippet
# ============================================================

post '/snippets' do
  content = params[:content].to_s.strip

  if content.empty?
    @error = "Conținutul nu poate fi gol!"
    return erb :index
  end

  # Maximum aproximativ 1 MB
  if content.bytesize > 1_000_000
    @error = "Snippet-ul este prea mare. Limita este de 1 MB."
    return erb :index
  end

  title = params[:title].to_s.strip

  title = "Fără titlu" if title.empty?

  if title.bytesize > 200
    @error = "Titlul este prea lung."
    return erb :index
  end

  created_at = Time.now.utc

  expires_at =
    case params[:expiry]
    when '1h'
      created_at + 3600
    when '24h'
      created_at + 86400
    else
      nil
    end

  # Generăm un slug unic
  loop do
    slug = SecureRandom.alphanumeric(8)

    begin
      DB.execute(
        <<-SQL,
          INSERT INTO snippets
          (slug, title, content, created_at, expires_at)
          VALUES (?, ?, ?, ?, ?)
        SQL
        [
          slug,
          title,
          content,
          created_at.iso8601,
          expires_at&.iso8601
        ]
      )

      redirect "/s/#{slug}"

    rescue SQLite3::ConstraintException
      # Dacă slug-ul există deja,
      # generăm altul.
      next
    end
  end
end

# ============================================================
# Vizualizare snippet
# ============================================================

get '/s/:slug' do
  @snippet = DB.execute(
    "SELECT * FROM snippets WHERE slug = ?",
    [params[:slug]]
  ).first

  halt 404, "Snippet-ul nu a fost găsit!" unless @snippet

  if @snippet['expires_at']
    expire_time = Time.parse(@snippet['expires_at'])

    if Time.now.utc > expire_time
      halt 410, "Acest snippet a expirat și nu mai este disponibil."
    end
  end

  erb :show
end

# ============================================================
# RAW
# ============================================================

get '/s/:slug/raw' do
  snippet = DB.execute(
    "SELECT * FROM snippets WHERE slug = ?",
    [params[:slug]]
  ).first

  halt 404, "Snippet negăsit!" unless snippet

  if snippet['expires_at']
    expire_time = Time.parse(snippet['expires_at'])

    if Time.now.utc > expire_time
      halt 410, "Expirat."
    end
  end

  content_type 'text/plain; charset=utf-8'

  snippet['content']
end

# ============================================================
# HTML Templates
# ============================================================

__END__

@@layout
<!DOCTYPE html>
<html lang="ro">

<head>
  <meta charset="UTF-8">

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
  >

  <title>Ruby Snippet Sharer</title>

  <link
    rel="stylesheet"
    href="https://cdn.jsdelivr.net/npm/water.css@2/out/water.css"
  >

  <style>
    pre {
      background: #202020;
      color: #f8f8f2;
      padding: 15px;
      border-radius: 8px;
      overflow-x: auto;
      white-space: pre-wrap;
      word-wrap: break-word;
    }

    textarea {
      width: 100%;
      min-height: 250px;
      font-family: monospace;
      font-size: 14px;
      box-sizing: border-box;
    }

    .meta {
      font-size: 0.9em;
      opacity: 0.7;
      margin-bottom: 1em;
    }

    .alert {
      color: #ff5555;
      font-weight: bold;
    }

    .raw-link {
      margin-top: 15px;
    }
  </style>
</head>

<body>

<header>
  <h2>
    <a href="/" style="text-decoration:none;">
      📋 Ruby Pastebin
    </a>
  </h2>
</header>

<main>
  <%= yield %>
</main>

</body>
</html>


@@index

<h3>Adaugă un fragment de cod sau text</h3>

<% if @error %>
  <p class="alert">
    <%= h @error %>
  </p>
<% end %>

<form action="/snippets" method="POST">

  <label for="title">
    Titlu (opțional):
  </label>

  <input
    type="text"
    id="title"
    name="title"
    placeholder="Ex: config.json sau script.py"
    maxlength="200"
  >

  <label for="content">
    Conținut:
  </label>

  <textarea
    id="content"
    name="content"
    placeholder="Lipește codul sau textul aici..."
    maxlength="1000000"
    required
  ></textarea>

  <label for="expiry">
    Expirare:
  </label>

  <select id="expiry" name="expiry">

    <option value="never">
      Niciodată
    </option>

    <option value="24h" selected>
      După 24 de ore
    </option>

    <option value="1h">
      După 1 oră
    </option>

  </select>

  <br>
  <br>

  <button type="submit">
    Creează Link
  </button>

</form>


@@show

<h3>
  <%= h @snippet['title'] %>
</h3>

<div class="meta">

  Creat la:
  <%= h @snippet['created_at'] %>

  |

  <% if @snippet['expires_at'] %>

    Expiră la:
    <%= h @snippet['expires_at'] %>

  <% else %>

    Expirare: Niciodată

  <% end %>

</div>

<pre><code><%= h @snippet['content'] %></code></pre>

<p class="raw-link">

  <a
    href="/s/<%= h @snippet['slug'] %>/raw"
    target="_blank"
    rel="noopener noreferrer"
  >
    📄 Vezi Text Brut / Raw
  </a>

</p>

<p>
  <a href="/">
    ➕ Adaugă alt snippet
  </a>
</p>

