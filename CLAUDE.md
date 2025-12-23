# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shelfarr is a self-hosted book/audiobook request and acquisition system for the *arr ecosystem. It combines Jellyseerr-style request UI with Radarr/Sonarr-style acquisition and post-processing, specifically for books destined for Audiobookshelf.

**Status**: Phase 1 Complete (Foundation) - Ready for Phase 2 (Metadata)

## Tech Stack

| Component | Choice |
|-----------|--------|
| Framework | Rails 8.1 |
| Ruby | 3.3.6 (managed via rbenv) |
| Database | SQLite |
| Frontend | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| Background Jobs | Solid Queue |
| Testing | Minitest (Rails default) |
| Deployment | Docker (single container) |

## Development Commands

```bash
# Setup (first time)
rbenv install 3.3.6          # Install Ruby if needed
bundle install               # Install gems
bin/rails db:setup           # Create DB and run seeds

# Development
bin/dev                      # Start dev server with Tailwind watch (port 3000)
bin/rails server             # Start Rails server only
bin/rails test               # Run tests
bin/rails db:migrate         # Run pending migrations
bin/rails db:seed            # Re-run seeds (idempotent)

# Background jobs (development)
bin/jobs                     # Start Solid Queue worker

# Docker
docker build -t shelfarr .
docker-compose up -d         # Start with docker-compose
```

## Project Structure

```
app/
  controllers/
    admin/                   # Admin-only controllers (users, settings)
    dashboard_controller.rb  # Main dashboard
    registrations_controller.rb  # User signup
    sessions_controller.rb   # Login (generated)
  models/
    user.rb                  # has_secure_password, role enum, first-user-is-admin
    book.rb                  # book_type enum (audiobook/ebook)
    request.rb               # status enum with 7 states
    download.rb              # Tracks active downloads
    setting.rb               # Typed key-value storage
    upload.rb                # Manual upload tracking
    system_health.rb         # Integration health monitoring
  services/
    settings_service.rb      # Typed settings access with defaults
  views/
    admin/                   # Admin UI views
    dashboard/               # Main dashboard
    registrations/           # Signup form
    sessions/                # Login form
```

## Key Patterns

### Authentication
- Rails 8 built-in authentication (not Devise)
- First user to register becomes admin automatically
- Only admins can create new users after first signup
- `Current.user` available via thread-local storage

### Settings
```ruby
SettingsService.get(:prowlarr_url)           # Get with default fallback
SettingsService.set(:max_retries, 15)        # Set with type validation
SettingsService.configured?(:prowlarr_api_key)  # Check if non-empty
SettingsService.seed_defaults!               # Initialize all defaults
```

### Request Status Flow
`pending` → `searching` → `downloading` → `processing` → `completed`
                      ↘ `not_found` (retries) → `failed` (max retries)

### Admin Authorization
```ruby
# In controllers:
class Admin::BaseController < ApplicationController
  before_action :require_admin
end
```

## Database

Single SQLite file at `storage/development.sqlite3` (or production.sqlite3)

Models with enums:
- User: `role` (user, admin)
- Book: `book_type` (audiobook, ebook)
- Request: `status` (pending, searching, not_found, downloading, processing, completed, failed)
- Download: `status` (queued, downloading, paused, completed, failed)
- Upload: `status` (pending, processing, completed, failed)
- SystemHealth: `status` (healthy, degraded, down)

## Development Phases

1. ~~Foundation~~ ✓ (Rails setup, auth, models, settings, Docker)
2. **Metadata** ← Next (Open Library client, search, caching)
3. Requests (request flow, queue, retry logic)
4. Acquisition (Prowlarr client, result selection, qBittorrent)
5. Processing (download monitoring, post-processing, delivery)
6. Admin & Health (issues page, health monitoring, bulk actions)
7. Polish (dashboard, mobile responsive, error handling)
8. Ecosystem (additional clients, notifications, open source)

## Dev Credentials

Development seed creates:
- Email: `admin@shelfarr.local`
- Password: `password123`
