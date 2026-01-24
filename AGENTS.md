# 🇪🇸 Documentación para Agentes (AI)

Este archivo (`AGENTS.md`) sirve como contexto para agentes de IA que trabajen en este repositorio.

## Estructura y Estilo

* **Idioma**: Principal en **Español** (España). Documentación en Inglés siempre en `<details>`.
* **Logs**: Usar verbos específicos (`[HASHED]`, `[SIGNED]`, `[VERIFIED]`). No usar `[OK]`.
* **Colores**:
  * Estado/Acción: Verde/Rojo/Amarillo (toda la línea).
  * Rutas/Archivos: Cyan (`\033[0;36m`) incrustado.
* **Scripts**:
  * `redact_nif.py`: Python 3 + PyMuPDF.
  * `sign_docs.sh` / `check_docs.sh`: Bash estricto (`set -euo pipefail`).
* **Comentarios en Código**: Exclusivamente en **Inglés**. Concisos, útiles y siguiendo las "Best Practices" del lenguaje (PEP 8 para Python, guía de estilo de Google para Shell).

## Contexto del Proyecto

Herramientas de integridad documental. La seguridad y la consistencia de los datos son críticas.

* **Nunca** introduzcas dependencias innecesarias.
* **Nunca** modifiques la lógica criptográfica sin una revisión exhaustiva.

---

<details>
<summary>🇬🇧 <strong>English</strong></summary>

# AI Agent Documentation

This file (`AGENTS.md`) provides context for AI agents working on this repository.

## Structure & Style

* **Language**: Primary **Spanish** (Spain). English documentation always in `<details>`.
* **Logs**: Use specific verbs (`[HASHED]`, `[SIGNED]`, `[VERIFIED]`). Do not use `[OK]`.
* **Colors**:
  * Status/Action: Green/Red/Yellow (full line).
  * Paths/Files: Cyan (`\033[0;36m`) embedded.
* **Scripts**:
  * `redact_nif.py`: Python 3 + PyMuPDF.
  * `sign_docs.sh` / `check_docs.sh`: Strict Bash (`set -euo pipefail`).
* **Code Comments**: Exclusively in **English**. Concise, helpful, and following language Best Practices (PEP 8 for Python, Google Shell Style Guide).

## Project Context

Document integrity tools. Security and data consistency are critical.

* **Never** introduce unnecessary dependencies.
* **Never** modify cryptographic logic without exhaustive review.

</details>
