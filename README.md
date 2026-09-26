# Ruby Pastebin

A simple and lightweight Pastebin-style application built with **Ruby, Sinatra, and SQLite**.

The application allows users to create code or text snippets and share them through unique URLs. Snippets can optionally expire after **1 hour**, **24 hours**, or remain available permanently.

## Features

* Create code or text snippets
* Unique URL for every snippet
* HTML snippet viewer
* Raw text endpoint
* Optional expiration:

  * 1 hour
  * 24 hours
  * Never
* HTML escaping to help prevent XSS
* SQLite database
* Persistent SQLite storage on Render
* Render deployment configuration included
* 1 MB content limit
* 200-character title limit
* Responsive web interface

## Tech Stack

* **Ruby**
* **Sinatra**
* **SQLite**
* **Puma**
* **Rack**
* **Water.css**
* **Render**

## Project Structure

```text
ruby-pastebin/
│
├── app.rb
├── config.ru
├── Gemfile
├── Gemfile.lock
├── render.yaml
├── .gitignore
└── snippets.db
```

> `snippets.db` is created automatically and should not be committed to Git.

## Local Installation

### 1. Clone the repository

```bash
git clone https://github.com/USERNAME/ruby-pastebin.git
cd ruby-pastebin
```

Replace `USERNAME` with your GitHub username.

### 2. Install dependencies

```bash
bundle install
```

### 3. Start the application

```bash
bundle exec rackup -p 4567
```

### 4. Open the application

Visit:

```text
http://localhost:4567
```

## Configuration

The application supports the following environment variable:

```text
DATABASE_PATH
```

If `DATABASE_PATH` is not set, the application uses:

```text
snippets.db
```

### Local

By default:

```text
snippets.db
```

### Render

On Render, the SQLite database is stored at:

```text
/var/data/snippets.db
```

using:

```text
DATABASE_PATH=/var/data/snippets.db
```

## Deployment on Render

This project includes a `render.yaml` file for deployment.

The configuration uses:

* Ruby
* Sinatra
* Puma
* SQLite
* Render Persistent Disk

### Render Configuration

```yaml
services:
  - type: web
    name: ruby-pastebin
    runtime: ruby
    plan: starter

    buildCommand: bundle install

    startCommand: bundle exec puma -C config.ru -p $PORT

    envVars:
      - key: DATABASE_PATH
        value: /var/data/snippets.db

    disk:
      name: snippets-data
      mountPath: /var/data
      sizeGB: 1
```

Connect the GitHub repository to Render and use the included `render.yaml` configuration to deploy the application.

## SQLite and Persistent Storage

SQLite is used to store all snippets.

On Render, the database is stored at:

```text
/var/data/snippets.db
```

This directory is mounted on a Render Persistent Disk.

The application automatically uses the persistent database path through the `DATABASE_PATH` environment variable.

> The SQLite database should not be stored in the application's normal filesystem when deploying to an environment with ephemeral storage.

## Routes

### Home Page

```text
GET /
```

Displays the snippet creation form.

### Create a Snippet

```text
POST /snippets
```

Creates a new snippet.

### View a Snippet

```text
GET /s/:slug
```

Example:

```text
/s/a9k2z4m1
```

### Raw Snippet

```text
GET /s/:slug/raw
```

Example:

```text
/s/a9k2z4m1/raw
```

Returns the original snippet content as:

```text
text/plain
```

## Snippet Expiration

When creating a snippet, users can choose between three expiration options:

| Value   | Expiration |
| ------- | ---------- |
| `1h`    | 1 hour     |
| `24h`   | 24 hours   |
| `never` | Never      |

Expired snippets return:

```text
410 Gone
```

The current version does not automatically delete expired snippets from the SQLite database.

## Security

The application HTML-escapes user-provided content before displaying it:

```ruby
def h(text)
  Rack::Utils.escape_html(text.to_s)
end
```

For example, content such as:

```html
<script>alert("test")</script>
```

is displayed as text rather than being executed by the browser.

### Content Limit

```text
1 MB
```

### Title Limit

```text
200 bytes
```

The `/raw` endpoint intentionally returns the original content as `text/plain`.

## Development

Start the application locally with:

```bash
bundle exec rackup -p 4567
```

Or:

```bash
bundle exec ruby app.rb
```

The application will be available at:

```text
http://localhost:4567
```

## Dependencies

The application uses the following Ruby gems:

```ruby
gem 'sinatra'
gem 'sqlite3'
gem 'rackup'
gem 'puma'
```

Install them with:

```bash
bundle install
```

## Updating the Deployment

After making changes:

```bash
git add .
git commit -m "Update application"
git push
```

If automatic deployments are enabled, Render will detect the new commit and deploy the updated application.

## Roadmap

Potential future improvements:

* Copy-to-clipboard button
* Syntax highlighting
* Dark/light mode
* View counter
* Delete snippets
* Password-protected snippets
* REST API
* Rate limiting
* CSRF protection
* Admin dashboard
* Automatic cleanup of expired snippets
* PostgreSQL support
* User authentication
* Custom snippet URLs
* File upload support
