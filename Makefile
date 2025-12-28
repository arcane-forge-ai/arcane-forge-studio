build-release-windows:
	flutter build windows \
	--dart-define=FLUTTER_ENV=production \
	--dart-define=SUPABASE_URL=https://wdoiouwzfutdtmdsdgkr.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkb2lvdXd6ZnV0ZHRtZHNkZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MjMyOTMsImV4cCI6MjA2NzA5OTI5M30.K1DBISfzvJJJJ3z2JxWGd9XyLVVHUoaqKUMPeQ5MQWI
	python utils/package_release.py

build-release-macos:
	flutter build macos --release \
	--dart-define=FLUTTER_ENV=production \
	--dart-define=SUPABASE_URL=https://wdoiouwzfutdtmdsdgkr.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkb2lvdXd6ZnV0ZHRtZHNkZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MjMyOTMsImV4cCI6MjA2NzA5OTI5M30.K1DBISfzvJJJJ3z2JxWGd9XyLVVHUoaqKUMPeQ5MQWI
	python3 utils/package_release_macos.py

deploy-web:
	flutter build web --release \
	--dart-define=FLUTTER_ENV=production \
	--dart-define=ENVIRONMENT=production \
	--dart-define=SUPABASE_URL=https://wdoiouwzfutdtmdsdgkr.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkb2lvdXd6ZnV0ZHRtZHNkZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MjMyOTMsImV4cCI6MjA2NzA5OTI5M30.K1DBISfzvJJJJ3z2JxWGd9XyLVVHUoaqKUMPeQ5MQWI \
	--dart-define=USE_API_SERVICE=true \
	--dart-define=A1111_MODE=online
	firebase deploy

# Alias for backward compatibility
build-release: build-release-windows
