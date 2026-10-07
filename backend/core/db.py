"""Outils de migration propres à Supabase."""

from django.db import migrations


def enable_rls(*tables: str) -> migrations.RunPython:
    """Active la Row Level Security sur des tables créées par Django (ADR 0007).

    Supabase expose le schéma `public` via son API REST (clé `anon` dans l'app).
    Sans RLS, une table créée par Django y serait lisible et modifiable par
    n'importe qui. RLS sans politique = tout refuser aux rôles `anon` et
    `authenticated` ; Django, propriétaire des tables, n'est pas concerné.
    Les politiques de lecture (Realtime) seront ajoutées table par table.
    """

    def forwards(apps, schema_editor):
        if schema_editor.connection.vendor != "postgresql":
            return
        for table in tables:
            schema_editor.execute(
                f"ALTER TABLE {schema_editor.quote_name(table)} ENABLE ROW LEVEL SECURITY"
            )

    def backwards(apps, schema_editor):
        if schema_editor.connection.vendor != "postgresql":
            return
        for table in tables:
            schema_editor.execute(
                f"ALTER TABLE {schema_editor.quote_name(table)} DISABLE ROW LEVEL SECURITY"
            )

    return migrations.RunPython(forwards, backwards, elidable=False)
