# 🇪🇸 Herramientas de Integridad y Anonimización Documental

Una suite de herramientas *open-source* diseñada para gestionar el ciclo de vida de documentos sensibles: **anonimización automática** de identificadores españoles (DNI/NIE), **firma criptográfica** y **verificación** de integridad.

Ideal para la publicación transparente de documentos oficiales o personales, asegurando que no contienen datos privados (NIFs) y garantizando que no han sido manipulados tras su publicación.

---

## 🚀 Flujo de Trabajo

El sistema funciona en tres etapas:

1. **Limpieza ([`redact_nif.py`](./redact_nif.py))**: Detecta y censura permanentemente DNI/NIEs en PDFs.
2. **Sellado ([`sign_docs.sh`](./sign_docs.sh))**: Firma digitalmente los documentos limpios y genera hashes de integridad.
3. **Verificación ([`check_docs.sh`](./check_docs.sh))**: Cualquiera puede comprobar que los documentos son auténticos y no han sido alterados.

## 🛠️ Requisitos Previos

Las herramientas están diseñadas para **Linux**, **macOS** y **WSL** (Windows Subsystem for Linux).

* **Python 3.6+**
* **GnuPG** (`gpg`): Para las firmas digitales.
* **OpenSSL** (Opcional): Para el sellado de tiempo (TSA).

### Instalación de dependencias

```shell
# 1. Crear entorno virtual (Recomendado)
python3 -m venv venv
source venv/bin/activate

# 2. Instalar librería de procesamiento PDF
pip install PyMuPDF

# 3. Asegurar permisos de ejecución
chmod +x redact_nif.py sign_docs.sh check_docs.sh
```

---

## 📖 Guía de Uso

### Paso 1: Anonimización (Redact)

Escanea recursivamente un directorio en busca de PDFs, detecta NIF/NIEs válidos (calculando la letra de control) y aplica una censura negra permanente (no reversible).

```shell
./redact_nif.py -i /ruta/a/documentos_origen
```

* Genera una carpeta `redacted_output` con la misma estructura que el origen.
* Crea un log `redaction_log.jsonl` con todos los hallazgos.

### Paso 2: Sellado (Sign)

Toma los documentos limpios y genera un paquete de distribución verificable.

```shell
./sign_docs.sh -i redacted_output -o documentos_finales -u tu_email@ejemplo.com
```

* **`-i`**: Carpeta con los PDFs limpios.
* **`-o`**: Carpeta de destino.
* **`-u`**: Tu ID o Email de tu clave GPG privada.
* **`-t`** (Opcional): URL de una Autoridad de Sellado de Tiempo (ej. FNMT) para certificar *cuándo* se firmó.

**Resultado en `documentos_finales/`:**

* `pdf_signed/`: Copia de los PDFs.
* `pgp_asc/`: Firmas digitales individuales (`.asc`) para cada PDF.
* `SHA512SUMS`: Lista maestra de hashes sha512.
* `SHA512SUMS.asc`: Firma de la lista maestra.
* `publickey.asc`: Tu clave pública para que otros puedan verificarte.

### Paso 3: Verificación (Check)

Este script se entrega junto con los documentos. Permite a terceros validar toda la cadena de confianza con un solo comando.

```shell
./check_docs.sh -i documentos_finales
```

El script verificará:

1. ✅ Que la clave pública incluida es válida.
2. ✅ Que el manifiesto `SHA512SUMS` está firmado por esa clave.
3. ✅ Que todos los archivos coinciden con su hash SHA512 (integridad bit a bit).
4. ✅ Que cada PDF individual tiene una firma PGP válida.
5. ✅ (Opcional) La validez del sello de tiempo TSA.

---

## ⚖️ Consideraciones Jurídicas

Este conjunto de herramientas está diseñado para proporcionar garantías técnicas que respaldan la validez legal de los documentos, especialmente útil frente a alteraciones malintencionadas por terceros.

* **Integridad**: El hash SHA-512 garantiza matemáticamente que el documento no ha sido modificado en un solo bit desde su sellado.
* **No Repudio**: La firma digital PGP vincula inequívocamente al firmante con el documento. El autor no puede negar haberlo firmado si se verifica con su clave pública.
* **Prueba de Existencia**: Si se utiliza el sellado de tiempo (TSA), se certifica que el documento existía en un momento exacto, impidiendo la retrodatación fraudulenta.

> *Nota: Estas herramientas proporcionan la evidencia técnica necesaria para procesos periciales, aunque la validez final depende del marco legal específico aplicable.*

---

## 💡 Consejos

* **Nunca publiques/compartas la clave privada** bajo ningún contexto. ¡Guárdala como oro en paño!
* **Todos los documentos** procesados y archivos generados por los scripts **deberían ser publicados conjuntamente**. Sin todos ellos, la cadena de confianza se rompe.
* **Nunca modifiques** en absolutamente nada los archivos generados. De cambiar un solo bit, las distintas verificaciones fallarán rotundamente. Si necesitas modificar algo, **vuelve a repetir el proceso completo** y reemplaza los nuevos archivos generados por los antiguos.

---

## 🤝 Contribuciones

[¡Las contribuciones son bienvenidas!](./CONTRIBUTING.md)
Mantén el código **modular, legible y testeado**.
Los *pull requests* deben incluir una descripción clara y un ejemplo de funcionamiento.

---

## 📝 Licencia

MIT © 2026 [sandokan.cat](https://sandokan.cat)

> *Úsalo. Modifícalo. Compártelo. Se agradece la atribución.*

<div align="center">
    <a href="./LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-green?logo=opensourceinitiative&logoColor=white" alt="Licencia MIT">
    </a>
</div>

---

## ⚠️ Descargo de Responsabilidad

Todas las herramientas y utilidades de este repositorio se proporcionan "tal cual", sin garantías. Úsalas bajo tu propia responsabilidad. Pensado para uso **personal**, **educativo** y **profesional**.

---

<details>
<summary>🇬🇧 <strong>English</strong></summary>

# Document Integrity and Anonymisation Tools

An open-source suite designed to manage the lifecycle of sensitive documents: **automatic anonymisation** of Spanish identifiers (DNI/NIE), **cryptographic signing**, and **integrity verification**.

Ideal for transparent publication of official or personal documents, ensuring they contain no private data (NIFs) and guaranteeing they haven't been tampered with after publication.

---

## 🚀 Workflow

The system works in three stages:

1. **Clean ([`redact_nif.py`](./redact_nif.py))**: Detects and permanently redacts DNI/NIEs in PDFs.
2. **Seal ([`sign_docs.sh`](./sign_docs.sh))**: Digitally signs cleaned documents and generates integrity hashes.
3. **Verify ([`check_docs.sh`](./check_docs.sh))**: Allows anyone to verify documents are authentic and unaltered.

## 🛠️ Prerequisites

Tools are designed for **Linux**, **macOS**, and **WSL** (Windows Subsystem for Linux).

* **Python 3.6+**
* **GnuPG** (`gpg`): For digital signatures.
* **OpenSSL** (Optional): For Timestamping (TSA).

### Dependency Installation

```shell
# 1. Create virtual environment (Recommended)
python3 -m venv venv
source venv/bin/activate

# 2. Install PDF processing library
pip install PyMuPDF

# 3. Ensure execution permissions
chmod +x redact_nif.py sign_docs.sh check_docs.sh
```

---

## 📖 Usage Guide

### Step 1: Anonymisation (Redact)

Recursively scans a directory for PDFs, detects valid NIF/NIEs (calculating the check digit), and applies permanent black censorship (non-reversible).

```shell
./redact_nif.py -i /path/to/source_docs
```

* Generates a `redacted_output` folder with the same structure as source.
* Creates a `redaction_log.jsonl` log with all findings.

### Step 2: Signing (Seal)

Takes cleaned documents and generates a verifiable distribution package.

```shell
./sign_docs.sh -i redacted_output -o final_docs -u your_email@example.com
```

* **`-i`**: Folder containing cleaned PDFs.
* **`-o`**: Destination folder.
* **`-u`**: Your private GPG Key ID or Email.
* **`-t`** (Optional): URL of a Timestamping Authority (e.g. FNMT) to certify *when* it was signed.

**Result in `final_docs/`:**

* `pdf_signed/`: Copy of the PDFs.
* `pgp_asc/`: Individual digital signatures (`.asc`) for each PDF.
* `SHA512SUMS`: Master list of sha512 hashes.
* `SHA512SUMS.asc`: Signature of the master list.
* `publickey.asc`: Your public key for others to verify you.

### Step 3: Verification (Check)

This script is delivered alongside the documents. Allows third parties to validate the entire chain of trust with a single command.

```shell
./check_docs.sh -i final_docs
```

The script will verify:

1. ✅ That the included public key is valid.
2. ✅ That the `SHA512SUMS` manifest is signed by that key.
3. ✅ That all files match their SHA512 hash (bit-for-bit integrity).
4. ✅ That each individual PDF has a valid PGP signature.
5. ✅ (Optional) The validity of the TSA timestamp.

---

## ⚖️ Legal Considerations

This toolset is designed to provide technical guarantees that support the legal validity of documents, particularly useful against malicious alterations by third parties.

* **Integrity**: The SHA-512 hash mathematically guarantees that the document has not been modified by a single bit since it was sealed.
* **Non-repudiation**: The PGP digital signature unequivocally links the signer to the document. The author cannot deny having signed it if verified with their public key.
* **Proof of Existence**: If timestamping (TSA) is used, it certifies that the document existed at an exact moment, preventing fraudulent backdating.

> *Note: These tools provide the necessary technical evidence for forensic processes, although final validity depends on the specific applicable legal framework.*

---

## 💡 Tips

* **Never publish/share your private key** under any context. Guard it with your life!
* **All processed documents** and generated files **should be published together**. Without all of them, the chain of trust is broken.
* **Never modify** the generated files in any way. Changing a single bit will cause validations to fail. If you need to modify something, **repeat the entire process** and replace the new generated files with the old ones.

---

## 🤝 Contributing

[Contributions are welcome!](./CONTRIBUTING.md)
Keep code **modular, readable, and tested**.
Pull requests should include a clear description and working example.

---

## 📝 License

MIT © 2026 [sandokan.cat](https://sandokan.cat)

> *Use it. Modify it. Share it. Attribution is appreciated.*

<div align="center">
    <a href="./LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
    </a>
</div>

---

## ⚠️ Disclaimer

All tools and utilities in this repo are provided "as is", without warranties. Use at your own risk. Intended for **personal**, **educational**, and **professional** use.

</details>
