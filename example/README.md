# darc – Comprehensive Console Example

This folder contains a runnable Dart **console app** demonstrating production-style usage of the `darc` package:

- Package initialization (basic + advanced config)
- JSONPlaceholder CRUD (GET/POST/PUT/DELETE)
- File download with progress + cancellation (MP4)

## Prerequisites

- Dart SDK (compatible with Dart `^3.9.2`)

## Run

From the `example` directory:

```bash
dart pub get
dart run
```

### Options

```bash
dart run -- --advanced
dart run -- --cancel
```

## What to expect

- **Initialization**: builds a `DioConsumer` configured for `https://jsonplaceholder.typicode.com`.
- **JSONPlaceholder**:
  - GET `/posts` (renders the first few titles)
  - POST `/posts`
  - PUT `/posts/1` (JSONPlaceholder accepts partial updates; this behaves like a PATCH-style update)
  - DELETE `/posts/1`
- **Download**: downloads the `butterfly.mp4` demo asset and saves it to a temporary directory.

## Notes about `darc`

- All HTTP calls return `ApiResultOf<E, T>` which is a `Future<Either<RequestException<E>, T>>`.
- You provide a `parser` callback for every request so untyped response bodies never leak into the app.
- Errors are returned as `RequestException` subclasses (no exceptions are thrown for request failures).
