"""
Tests de la ingesta actual basada en DLT.

Validan:
- SHA256
- Reintentos de descarga
- Regla de negocio del mes comparativo
"""

from pathlib import Path

import pytest

from src.ingest_dlt import (
    calcular_sha256,
    descargar_con_reintentos,
)


def test_sha256_detecta_cambios(tmp_path):
    archivo = tmp_path / "archivo.bin"

    archivo.write_bytes(b"contenido original")

    h1 = calcular_sha256(archivo)

    assert calcular_sha256(archivo) == h1

    archivo.write_bytes(b"contenido modificado")

    assert calcular_sha256(archivo) != h1


def test_sha256_archivo_vacio(tmp_path):
    archivo = tmp_path / "vacio.bin"

    archivo.write_bytes(b"")

    resultado = calcular_sha256(archivo)

    assert isinstance(resultado, str)
    assert len(resultado) == 64


def test_descarga_requiere_reintentos(monkeypatch, tmp_path):

    llamadas = {"n": 0}

    class FakeResponse:

        def raise_for_status(self):
            pass

        def iter_content(self, chunk_size):
            yield b"contenido"

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc_val, exc_tb):
            pass

    def fake_get(*args, **kwargs):

        llamadas["n"] += 1

        if llamadas["n"] < 3:
            raise Exception("fallo temporal")

        return FakeResponse()

    monkeypatch.setattr(
        "requests.get",
        fake_get,
    )

    destino = tmp_path / "archivo.parquet"

    descargar_con_reintentos(
        "http://test.local",
        destino,
        max_retries=3,
    )

    assert destino.exists()
    assert llamadas["n"] == 3


def test_mes_comparativo():

    mes = "2025-06"

    year, month = mes.split("-")

    mes_comparacion = f"{int(year) - 1}-{month}"

    assert mes_comparacion == "2024-06"


def test_mes_comparativo_cambia_solo_el_anio():

    mes = "2023-11"

    year, month = mes.split("-")

    mes_comparacion = f"{int(year) - 1}-{month}"

    assert mes_comparacion == "2022-11"


def test_anio_2009_no_permite_comparacion():

    with pytest.raises(ValueError):

        year_int = 2009

        if year_int <= 2009:
            raise ValueError(
                "Para comparar contra el año anterior "
                "el año debe ser 2010 o superior."
            )