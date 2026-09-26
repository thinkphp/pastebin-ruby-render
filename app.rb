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
    @error = "Content cannot be empty!"
    return erb :index
  end

  # Roughly 1 MB max
  if content.bytesize > 1_000_000
    @error = "Snippet is too large. The limit is 1 MB."
    return erb :index
  end

  title = params[:title].to_s.strip

  title = "Untitled" if title.empty?

  if title.bytesize > 200
    @error = "Title is too long."
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

  halt 404, "Snippet not found!" unless @snippet

  if @snippet['expires_at']
    expire_time = Time.parse(@snippet['expires_at'])

    if Time.now.utc > expire_time
      halt 410, "This snippet has expired and is no longer available."
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

  halt 404, "Snippet not found!" unless snippet

  if snippet['expires_at']
    expire_time = Time.parse(snippet['expires_at'])

    if Time.now.utc > expire_time
      halt 410, "Expired."
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
<html lang="en">

<head>
  <meta charset="UTF-8">

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
  >

  <title>Ruby Snippet Sharer</title>

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg-0: #0b0d14;
      --bg-1: #11131c;
      --bg-2: #171a25;
      --panel: rgba(255, 255, 255, 0.04);
      --panel-border: rgba(255, 255, 255, 0.08);
      --text: #e9e9f1;
      --text-dim: #9498ac;
      --accent: #8b7cf6;
      --accent-2: #34d3c9;
      --accent-glow: rgba(139, 124, 246, 0.35);
      --danger: #ff6b81;
      --radius: 14px;
    }

    * {
      box-sizing: border-box;
    }

    html, body {
      height: 100%;
    }

    body {
      margin: 0;
      font-family: 'Sora', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at 15% 0%, rgba(139, 124, 246, 0.16), transparent 45%),
        radial-gradient(circle at 85% 20%, rgba(52, 211, 201, 0.12), transparent 40%),
        linear-gradient(180deg, var(--bg-0), var(--bg-1) 40%, var(--bg-2));
      background-attachment: fixed;
      min-height: 100vh;
      line-height: 1.6;
    }

    header {
      padding: 28px 20px 8px;
      text-align: center;
    }

    header h2 {
      margin: 0;
      font-size: 1.5rem;
      letter-spacing: 0.02em;
    }

    header a {
      text-decoration: none;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
      font-weight: 700;
    }

    main {
      max-width: 760px;
      margin: 20px auto 60px;
      padding: 0 20px;
    }

    main > *:first-child {
      margin-top: 0;
    }

    h3 {
      font-weight: 600;
      font-size: 1.15rem;
      color: var(--text);
      margin-bottom: 18px;
    }

    /* Card wrapper effect via form / pre / meta containers */
    form,
    .snippet-card {
      background: var(--panel);
      border: 1px solid var(--panel-border);
      border-radius: var(--radius);
      padding: 28px;
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      box-shadow: 0 20px 50px -25px rgba(0, 0, 0, 0.6);
    }

    label {
      display: block;
      font-size: 0.82rem;
      font-weight: 600;
      letter-spacing: 0.03em;
      text-transform: uppercase;
      color: var(--text-dim);
      margin: 20px 0 8px;
    }

    label:first-of-type {
      margin-top: 0;
    }

    input[type="text"],
    select,
    textarea {
      width: 100%;
      background: rgba(0, 0, 0, 0.25);
      border: 1px solid var(--panel-border);
      border-radius: 10px;
      color: var(--text);
      padding: 12px 14px;
      font-size: 0.95rem;
      font-family: inherit;
      transition: border-color 0.2s ease, box-shadow 0.2s ease;
    }

    input[type="text"]:focus,
    select:focus,
    textarea:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }

    textarea {
      width: 100%;
      min-height: 260px;
      font-family: 'JetBrains Mono', ui-monospace, monospace;
      font-size: 13.5px;
      resize: vertical;
    }

    select {
      appearance: none;
      -webkit-appearance: none;
      background-image: linear-gradient(45deg, transparent 50%, var(--text-dim) 50%),
                         linear-gradient(135deg, var(--text-dim) 50%, transparent 50%);
      background-position: calc(100% - 18px) calc(1.1em), calc(100% - 13px) calc(1.1em);
      background-size: 5px 5px, 5px 5px;
      background-repeat: no-repeat;
      padding-right: 36px;
      cursor: pointer;
    }

    button[type="submit"] {
      margin-top: 26px;
      width: 100%;
      border: none;
      border-radius: 10px;
      padding: 13px 22px;
      font-size: 0.95rem;
      font-weight: 600;
      letter-spacing: 0.01em;
      color: #0b0d14;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      cursor: pointer;
      transition: transform 0.15s ease, box-shadow 0.15s ease, filter 0.15s ease;
      box-shadow: 0 10px 25px -10px var(--accent-glow);
    }

    button[type="submit"]:hover {
      transform: translateY(-1px);
      filter: brightness(1.08);
      box-shadow: 0 14px 30px -10px var(--accent-glow);
    }

    button[type="submit"]:active {
      transform: translateY(0);
    }

    pre {
      background: rgba(0, 0, 0, 0.35);
      color: #e6e6f0;
      padding: 20px;
      border-radius: 12px;
      border: 1px solid var(--panel-border);
      overflow-x: auto;
      white-space: pre-wrap;
      word-wrap: break-word;
      font-family: 'JetBrains Mono', ui-monospace, monospace;
      font-size: 13.5px;
    }

    .meta {
      font-size: 0.85em;
      color: var(--text-dim);
      margin-bottom: 18px;
      padding-bottom: 14px;
      border-bottom: 1px solid var(--panel-border);
    }

    .alert {
      color: var(--danger);
      font-weight: 600;
      background: rgba(255, 107, 129, 0.1);
      border: 1px solid rgba(255, 107, 129, 0.3);
      border-radius: 10px;
      padding: 12px 16px;
      margin-bottom: 18px;
    }

    .raw-link {
      margin-top: 18px;
    }

    a {
      color: var(--accent-2);
      transition: color 0.15s ease;
    }

    a:hover {
      color: var(--accent);
    }

    a[target="_blank"] {
      display: inline-block;
      font-size: 0.9rem;
      text-decoration: none;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--panel-border);
      padding: 8px 14px;
      border-radius: 8px;
    }

    a[target="_blank"]:hover {
      background: rgba(255, 255, 255, 0.09);
    }

    footer {
      text-align: center;
      padding: 24px 20px 40px;
      font-size: 0.8rem;
      color: var(--text-dim);
      letter-spacing: 0.02em;
    }

    footer span {
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      -webkit-background-clip: text;
      background-clip: text;
      color: transparent;
      font-weight: 600;
    }
  </style>
</head>

<body>

<header>
  <h2>
    <a href="/">
      📋 Ruby Pastebin
    </a>
  </h2>
</header>

<main>
  <%= yield %>
</main>

<footer>
  Built by <span>Adrian</span>
</footer>

</body>
</html>


@@index

<h3>Add a code or text snippet</h3>

<% if @error %>
  <p class="alert">
    <%= h @error %>
  </p>
<% end %>

<form action="/snippets" method="POST">

  <label for="title">
    Title (optional):
  </label>

  <input
    type="text"
    id="title"
    name="title"
    placeholder="e.g. config.json or script.py"
    maxlength="200"
  >

  <label for="content">
    Content:
  </label>

  <textarea
    id="content"
    name="content"
    placeholder="Paste your code or text here..."
    maxlength="1000000"
    required
  ></textarea>

  <label for="expiry">
    Expiration:
  </label>

  <select id="expiry" name="expiry">

    <option value="never">
      Never
    </option>

    <option value="24h" selected>
      After 24 hours
    </option>

    <option value="1h">
      After 1 hour
    </option>

  </select>

  <button type="submit">
    Create Link
  </button>

</form>


@@show

<div class="snippet-card">

  <h3>
    <%= h @snippet['title'] %>
  </h3>

  <div class="meta">

    Created at:
    <%= h @snippet['created_at'] %>

    |

    <% if @snippet['expires_at'] %>

      Expires at:
      <%= h @snippet['expires_at'] %>

    <% else %>

      Expiration: Never

    <% end %>

  </div>

  <pre><code><%= h @snippet['content'] %></code></pre>

  <p class="raw-link">

    <a
      href="/s/<%= h @snippet['slug'] %>/raw"
      target="_blank"
      rel="noopener noreferrer"
    >
      📄 View Raw Text
    </a>

  </p>

</div>

<p>
  <a href="/">
    ➕ Add another snippet
  </a>
</p>