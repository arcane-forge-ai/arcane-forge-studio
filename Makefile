build-release:
	flutter build windows \
	--dart-define=FLUTTER_ENV=production \
	--dart-define=SUPABASE_URL=https://wdoiouwzfutdtmdsdgkr.supabase.co \
	--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indkb2lvdXd6ZnV0ZHRtZHNkZ2tyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MjMyOTMsImV4cCI6MjA2NzA5OTI5M30.K1DBISfzvJJJJ3z2JxWGd9XyLVVHUoaqKUMPeQ5MQWI
	python utils/package_release.py
