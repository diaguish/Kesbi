from rest_framework import serializers

from .models import Boutique


class BoutiqueSerializer(serializers.ModelSerializer):
    # L'UUID vient de l'app (ADR 0002) et ne change plus ensuite.
    id = serializers.UUIDField()

    class Meta:
        model = Boutique
        fields = ["id", "nom", "activite", "created_at", "updated_at"]
        read_only_fields = ["updated_at"]
        extra_kwargs = {"created_at": {"required": False}}

    def validate_nom(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Le nom de la boutique est obligatoire.")
        return value

    def update(self, instance, validated_data):
        validated_data.pop("id", None)
        validated_data.pop("created_at", None)
        return super().update(instance, validated_data)
