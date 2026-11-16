# Translation Platform

The repository is split into two projects:

- [frontend/](./frontend/) — Flutter application.
- [backend/](./backend/) — Django API and MySQL configuration.

See the [backend setup guide](./backend/README.md) for environment variables,
database setup, and API routes. Create Django migrations when the schema is
ready; none are checked in yet.

The Flutter API base URL can be overridden with
`--dart-define=API_BASE_URL=https://your-api-host/api/v1`.
