# Evidencias de sistema · Base de datos

Base de datos relacional **PostgreSQL 16** en Azure, normalizada a tercera forma normal (47 tablas).

| Archivo | Contenido |
|---|---|
| [modelo-datos.sql](modelo-datos.sql) | DDL completo: tablas, claves primarias y foráneas, restricciones `CHECK` |
| [modelo-datos.md](modelo-datos.md) | Diccionario de datos y diagrama entidad-relación |

Estos archivos son una copia de `docs/` del repositorio
[agecare-backend](https://github.com/francobarra-dev/agecare-backend), donde se generan con
`scripts/export_model.py`. Las migraciones que crean el esquema están en `alembic/versions/` de ese repositorio.
