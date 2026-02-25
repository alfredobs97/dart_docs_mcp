# --- Build Stage ---
FROM dart:stable AS build

WORKDIR /app

# Resolve app dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and compile.
COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# --- Development Stage ---
# This stage keeps the source code and allows running with 'dart run'
# for easier development/testing without re-compiling.
FROM build AS dev
CMD ["dart", "run", "bin/server.dart"]

# --- Production Stage ---
# Minimal serving image from AOT-compiled binary.
FROM scratch AS runtime
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/
CMD ["/app/bin/server"]
