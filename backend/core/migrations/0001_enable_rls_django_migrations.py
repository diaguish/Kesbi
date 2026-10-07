from django.db import migrations

from core.db import enable_rls


class Migration(migrations.Migration):
    """La table technique de Django ne doit pas être exposée par l'API Supabase."""

    dependencies = []

    operations = [enable_rls("django_migrations")]
