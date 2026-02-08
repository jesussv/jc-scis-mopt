# Documento de Diseño Técnico  
## Sistema de Control de Inventario y Stock (SCIS)

**Por:** Jehovani Chavez

---

## Tabla de contenidos
- [Instrucciones de instalación](#instrucciones-de-instalación)
- [Selección de tecnologías](#selección-de-tecnologías)
  - [Backend](#backend)
  - [Frontend](#frontend)
- [Motor de base de datos](#motor-de-base-de-datos)
- [Diagramas de arquitectura](#diagramas-de-arquitectura)
- [Estrategia de branching](#estrategia-de-branching)
- [Deploy a Google Cloud Run](#Deploy-a-Google-Cloud-Run)
- [Demo Movil y Web](#Demo-Movil-y-Web)
- [Ciclo de Vida, Metodologías Ágiles y Planificación](#Ciclo-de-Vida,-Metodologías-Ágiles-y-Planificación)
  - [Metodología de trabajo](#Metodología-de-trabajo)
  - [Cronograma del MVP Diagrama Gantt](#Cronograma-del-MVP-Diagrama-Gantt)
  - [Estrategia de QA](#Estrategia-de-QA)
- [Infraestructura y Automatización](#Infraestructura-y-Automatización)
    - [Pipeline de CI/CD (GitHub → Cloud Run)](#Pipeline-de-CI/CD-(GitHub-→-Cloud-Run))
    - [Observabilidad Logs, Errores, Trazas y Métricas](#Observabilidad-Logs,-Errores,-Trazas-y-Métricas)

---

## Instrucciones de instalación

1. Nos registramos en Google Cloud e ingresamos a **Cloud SQL**.

   <p align="center">
     <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/Cloud%20SQL.jpg" width="720" />
   </p>

2. Creamos una instancia seleccionando el servidor con el plan que necesitemos con **PostgreSQL**.

   <p align="center">
     <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/InstanciaGoogleCloud.jpg" width="720" />
   </p>

3. Creamos una nueva base de datos y abrimos el archivo `backup_schema.sql` con Bloc de notas u otro editor para copiar el contenido y pegarlo en el editor.

   <p align="center">
     <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/bd.jpg" width="720" />
   </p>

4. Descargamos el proyecto adjunto.

## Deploy a Google Cloud Run

> Este deploy aplica para el **Backend (ASP.NET Core Minimal APIs .NET 8)**.

### Prerrequisitos
- Tener un proyecto en Google Cloud.
- Tener habilitado:
  - **Cloud Run**
  - **Cloud Build**
  - **Artifact Registry**
  - **Secret Manager**
- Tener instalado y autenticado `gcloud` (o usar **Cloud Shell**).

---

### 1) Autenticación y proyecto
- bash
- gcloud auth login
- gcloud config set project (Nombre proyecto)
- gcloud config set run/region
---
#### Pasos.
1. Hay que Ubicarse en la carpeta donde está el backend (donde está el .csproj):
   cd services/JC.LocationIngest
---
2. Deploy:
gcloud run deploy c-location-ingest-dev \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
la API debe ser privada, quitamos --allow-unauthenticated y usamos IAM.
---
3. Deploy con Cloud SQL (PostgreSQL) + Secrets
   Cloud SQL y variables sensibles en Secret Manager:

gcloud run deploy c-location-ingest-dev \
  --source . \
  --region us-central1 \
  --add-cloudsql-instances evocative-reef-133021:us-central1:jchavez-pt-mopt-dev2026 \
  --set-secrets "ConnectionStrings__JCPostgres=jc-connstr:latest,Jwt__Key=jc-jwt-key:latest" \
  --allow-unauthenticated
  
Obtener la URL del servicio
gcloud run services describe c-location-ingest-dev \
  --region us-central1 \
  --format="value(status.url)"

---
4. Validación rápida (health/status)

power-Shell
curl -s "$(gcloud run services describe c-location-ingest-dev --region us-central1 --format='value(status.url)')/health"
Ajustar /health por  endpoint real si se llama distinto.

---
5. Variables de entorno 

Para ver variables configuradas en el contenedor:

gcloud run services describe c-location-ingest-dev \
  --region us-central1 \
  --format="yaml(spec.template.spec.containers[0].env)"
### Demo Movil y Web
## 🚀 DESCARGA LA APP DEMO
> **Instala SCIS y empezá a probar como controlar un inventario. Usuario: demo contraseña: demo1234**  
✅ Login seguro • ✅ Entradas/Salidas • ✅ Ajustes • ✅ Transferencias • ✅ Stock por bodega • ✅ Movimientos

<p align="center">
  <a href="https://drive.google.com/file/d/1As7YoFjR2aEGx0lt0hOshhIq4LVGYQHV/view?usp=sharing">
    <img src="https://img.shields.io/badge/📥%20DESCARGAR%20APP-Releases-brightgreen?style=for-the-badge" />
  </a>
</p>
<!-- ✅ Preview Movil -->
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/apk1.png" width="720" />
</p>
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/apk2.png" width="720" />
</p>
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/apk3.png" width="720" />
</p>

## 🚀 VERSION WEB DEMO
### <!-- ✅ Preview WEB -->
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/WEB1.png" width="600" />
</p>
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/WEB2.png" width="600" />
</p>
<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/WEB3.png" width="600" />
</p>


## Selección de tecnologías

### Backend

**Justificación:**

1. **Tecnológico:** ASP.NET Core Minimal APIs en .NET 8 para una API REST ligera, rápida y estable (CRUD de productos, movimientos, entradas/salidas, kardex y consultas con buena concurrencia).  
   Hosting en **Cloud Run** (contenedores serverless) por escalado automático, despliegue por Docker y cero administración de VMs/parches.  
   Seguridad con **JWT Bearer** (stateless) y roles (bodega, admin, auditor).  
   Configuración sensible en **Secret Manager** (ej.: Jwt Key).

2. **Económico:** Cloud Run se paga por demanda (requests/CPU/memoria), evitando pagar infraestructura 24/7 en horas de bajo tráfico y reduciendo el costo operativo.

3. **Recurso humano:** C#/.NET es stack empresarial con talento disponible; Minimal APIs reduce boilerplate y acelera la entrega sin perder mantenibilidad ni escalabilidad.

**Stack:**
- **Framework:** ASP.NET Core Minimal APIs  
- **Lenguaje/Runtime:** C# / .NET 8  
- **Tipo de app:** API REST  
- **Hosting:** Cloud Run (serverless containers)  
- **Auth:** JWT Bearer  
- **Secrets:** Secret Manager  

---

### Frontend

**Justificación:**

1. **Tecnológico:** Flutter (Dart) para app multiplataforma real (Android/iOS y opcional Web) con una sola base de código. UI con Widgets (Material/Cupertino) para pantallas típicas de inventario: catálogo, existencias, registro/escaneo y movimientos.  
   Consumo del backend .NET vía HTTP/HTTPS y JSON.

2. **Seguridad/Auth:** Login obtiene el JWT y luego se envía en cada request:  
   `Authorization: Bearer <token>`  
   Sesiones stateless y permisos por rol/claims desde backend.

3. **Económico:** Un solo desarrollo para múltiples plataformas reduce costo y mantenimiento.

4. **Recurso humano:** Un solo stack (Flutter/Dart), componentes reutilizables y ciclo de desarrollo rápido.

**Stack:**
- **Tipo:** App multiplataforma (Android / iOS / Web)  
- **Framework:** Flutter  
- **Lenguaje:** Dart  
- **UI:** Material/Cupertino  
- **Consumo de API:** HTTP/HTTPS + JSON  
- **Auth:** JWT Bearer Token  

---

## Motor de base de datos

**Justificación:**

1. **Tecnológico:** PostgreSQL en Cloud SQL por integridad referencial, transacciones y consistencia en movimientos (entradas/salidas, ajustes, kardex). Concurrencia sólida y menos bloqueos entre lecturas/escrituras.

2. **Acceso a datos:** Dapper + Npgsql para rendimiento y control (micro-ORM liviano y driver estable).

3. **Seguridad:** Consultas parametrizadas con Dapper/Npgsql para prevenir SQL Injection.

4. **Escalabilidad y costo:** Cloud SQL soporta escalado (tamaño/rendimiento/réplicas) y reduce administración (backups/parches), mejorando control del gasto.

**Stack:**
- **Base de datos:** PostgreSQL (Cloud SQL)  
- **Acceso:** Dapper + Npgsql  

---

## Diagramas de arquitectura

La arquitectura propuesta se basa en el esquema **cliente → API → base de datos**, usando servicios cloud administrados para escalar y reducir operación.

**Patrón arquitectónico:** Modular Monolith (escalable según necesidades futuras).

### 1) Diagrama de contexto (C4 - Nivel 1)

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/SCIS_C4_Nivel1_Contexto.jpg" width="720" />
</p>

### 2) Diagrama de contenedores (C4 - Nivel 2)

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/SCIS_C4_Nivel2_Contenedores.jpg" width="720" />
</p>

### 3) Diagrama de componentes (C4 - Nivel 3)

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/SCIS_C4_Nivel3_Componentes.jpg" width="720" />
</p>

### 4) Diagrama de código (C4 - Nivel 4)

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/SCIS_C4_Nivel4_Codigo.jpg" width="720" />
</p>

---

## Estrategia de branching

Se utilizará **Trunk Based Development**, PRs cortos y frecuentes + CI fuerte + feature flags, para que 8 devs trabajen en paralelo sin conflictos bloqueantes ni ramas eternas.

### Flujo a utilizar

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/SCIS_Git_Branching_Flujo.jpg" width="720" />
</p>

---
## Ciclo de Vida, Metodologías Ágiles y Planificación
### Metodología de trabajo
Para este proyecto yo me voy con **Scrum** (gestión de proyectos de metodología ágil).

Scrum me sirve porque tengo un **MVP con fecha**, fases claras y necesito **entregas por bloques** (UX listo → API lista → Frontend listo → integración → QA → deploy), asegurando avance continuo y validación temprana.

## 🔄 Cómo aseguro la sincronización Backend + Frontend + UX (sin bloqueos lo principal)

El objetivo no es “hacer reuniones por hacerlas”, sino ejecutar **las mínimas necesarias** para sincronizar dependencias y mantener el avance continuo.

### ✅ Principios que evitán bloqueos

**1) UX no bloquea a Frontend (Desarrollo en Flutter)**  
Para que Frontend no se quede esperando (o inventando), UX debe definir a tiempo:
- Pantallas y flujos
- Estados: vacío / cargando / error
- Validaciones y mensajes
- Componentes reutilizables y comportamiento

**2) Backend no bloquea a Frontend**  
Para que el Frontend no se frene, Backend debe acordar temprano:
- Endpoints y contratos (DTO)
- Códigos de error y respuestas estándar
- Paginación, filtros y ordenamiento

> Mientras el backend termina, el frontend avanza con **mocks/stubs** basados en contratos acordados, sin romperse después.

**3) QA prueba en tiempo real (no al final)**  
QA valida cada incremento desde temprano, detectando fallas antes de llegar a “la semana de pruebas”.

---

### 🧩 Cadencia mínima de coordinación (todo bien ejecutado)

#### 1) Daily (15 min)
- Cada persona dice: **qué hizo, qué hará, qué la bloquea**
- Si el bloqueo es de UX o API, **se resuelve ese mismo día** (no “mañana vemos”)

#### 2) Planning (inicio de cada bloque de trabajo)
Como el proyecto está por fases, el planning se alinea así:
- Semana 1: Descubrimiento (qué se define y qué queda “listo”)
- Semana 2: Diseño UI/UX + Arquitectura
- Semana 3–4: Desarrollo Backend
- Semana 4–5: Desarrollo Frontend
- Semana 5: Integración
- Semana 6: QA
- Semana 7: Deploy

#### 3) Refinement (1 vez por semana)
- Dejar “cocinadas” las historias de la siguiente semana
- UX + Backend + Frontend alinean **criterios de aceptación** y detalles

#### 4) Demo semanal (30–45 min)
- Se muestra lo que **ya funciona** (aunque sea parcial)
- Detecta errores temprano antes de llegar a QA

#### 5) Retro (30–45 min semanal o por fase)
- No es para “hablar bonito”, es para acordar **1 mejora concreta por semana**
  - Ej.: “API contract congelado a mitad de semana 2”
  - Ej.: “No se cambian pantallas en semana 5”

### Planificación del MVP (flujo)
1. Descubrimiento + análisis UX  
2. Prototipo UI/UX  
3. Definición de arquitectura Backend  
4. Desarrollo Backend MVP  
5. Desarrollo Frontend MVP  
6. Integración Backend–Frontend  
7. Pruebas y QA del MVP  
8. Ajustes finales y despliegue del MVP

## Cronograma del MVP Diagrama Gantt

<p align="center">
  <img src="https://github.com/jesussv/jc-pt-mopt/blob/main/_20260207.png" width="1024" />
</p>

> Este Gantt define el **camino crítico del MVP** y asegura entregas por bloques:  
> **UX listo → API lista → Frontend listo → Integración → QA → Deploy**

---

### Semana 1 (10/02 – 14/02): Descubrimiento UX
**Objetivo:** dejar definido qué entra al MVP y cómo se ve el flujo.
- Workshop rápido: alcance MVP + user flows
- Backlog inicial con historias claras

### Semana 2 (17/02 – 21/02): Diseño UI/UX + Arquitectura Backend
**Objetivo:** aquí se “cierra” el diseño base y se define el mapa técnico.
- UX entrega prototipo navegable
- Backend define arquitectura, seguridad, modelo DB, contratos API

### Semana 3–4 (24/02 – 06/03): Desarrollo Backend MVP
**Objetivo:** API lista para que Frontend consuma.
- Endpoints principales
- Lógica base del inventario y movimientos
- Logging y errores controlados

### Semana 4–5 (02/03 – 13/03): Desarrollo Frontend MVP
**Objetivo:** app Flutter operativa con pantallas y consumo de API.
- UI según prototipo
- Navegación y formularios
- Validaciones básicas

### Semana 5 (09/03 – 13/03): Integración Backend–Frontend
**Objetivo:** que todo funcione junto.
- Ajustes de contratos
- Corrección de edge cases
- “Smoke test” diario

### Semana 6 (16/03 – 20/03): Pruebas y QA
**Objetivo:** estabilidad.
- Pruebas funcionales
- Regresión mínima
- Bugs a Kanban de urgencias

### Semana 7 (23/03 – 27/03): Ajustes finales y Deploy
**Objetivo:** salida limpia.
- Fixes finales
- Deploy a producción
- Validación post despliegue

## Estrategia de QA

- Cada **Pull Request** valida **calidad mínima** (quality gate).  
- Cada merge a **main** valida **integración real**.  
- Antes de producción validamos el **flujo completo del MVP** con E2E críticos.

---

### ✅ 1) Pruebas Unitarias (rápidas y muchas)

**Dónde aplican**
- **Backend:** reglas de negocio y validaciones  
  *(ej.: OUT no permite stock negativo, ADJUST respeta reglas, TRANSFER descuenta y suma, etc.)*
- **Frontend (Flutter):** validación de formularios, mapeos de modelos, formateo, estados (loading/error/empty) y lógica simple de UI.

**Por qué son clave**
- Son las más rápidas y baratas.
- Detectan fallos antes de que lleguen a integración.

**Meta práctica (MVP)**
- **Backend:** cubrir lo crítico (movimientos + reglas de stock + validaciones).
- **Flutter:** cubrir validaciones y lógica de pantalla *(sin intentar testear UI completa todavía)*.

---

### 🔗 2) Pruebas de Integración (API + DB + Controller)

**Qué validan**
- Endpoints funcionando con **base real** y datos reales.
- Transacciones y constraints sin romperse.
- Respuesta del API **coincide con el contrato** que consume Flutter.

**Casos críticos**
- Crear movimiento **IN / OUT / ADJUST / TRANSFER** y verificar saldo resultante por bodega.
- Reglas: **no permitir OUT** si no hay stock.
- Transfer: **descuenta en origen y suma en destino** (transaccional).

**Por qué son clave aquí**
- El riesgo grande está en **stock + transacciones**.
- Aquí es donde se rompe un MVP si no se prueba.

---

### 🧭 3) Pruebas E2E (pocas, pero las más importantes)

**Regla de oro:** En el MVP no hacemos 200 E2E. Hacemos **8–12 flujos críticos** que garantizan operación.

**Flujos E2E mínimos recomendados**
1. Login exitoso y navegación básica  
2. Consulta de productos + búsqueda  
3. Ver inventario: seleccionar producto y ver stock por bodega  
4. Movimiento **IN** y ver stock actualizado  
5. Movimiento **OUT** con validación de stock  
6. **TRANSFER** origen → destino y ver resultados en ambas bodegas  
7. **ADJUST** y ver saldo final  
8. Auditoría básica: visualizar movimientos recientes

---

## ⚙️ CI/CD: Etapa de ejecución de pruebas.

### 1) Pull Request (PR) — **Quality Gate rápido**
Se ejecuta en cada PR para impedir que entre “basura”:
- ✅ Lint/Format (backend y Flutter)
- ✅ Unit Tests (backend + Flutter)
- ✅ Build/Compile (backend + Flutter)
- ✅ (Opcional rápido) análisis estático / seguridad básica

> **Regla:** si falla aquí, **no se mergea**.

---

### 2) Merge a main — **Integración real**
Cuando el cambio entra a `main`:
- ✅ Integración (API + DB)
  - Ideal: DB efímera en CI (contenedor) o DB de test aislada
- ✅ Build de artefactos
- ✅ Deploy automático a **Staging** (Cloud Run)

---

### 3) Staging — **E2E + Smoke tests**
Después del deploy a Staging:
- ✅ E2E tests (solo flujos críticos)
- ✅ Smoke test (arranque, login, consulta, crear 1 movimiento)
- ✅ Reporte de resultados (pasó / no pasó)

> **Regla:** si E2E falla, **no se promueve** a producción.

---

### 4) Producción — **Despliegue seguro**
- Deploy a Cloud Run usando **revisiones** (release controlado).
- Monitoreo post-deploy:
  - Errores **5xx**
  - Latencia
  - Logs de negocio (movimientos, fallos de validación)

---

## 🗓️ Cómo culmina al cronograma del MVP

### Semanas 3–4 (Backend MVP)
- Unit tests de reglas de stock y movimientos desde el día 1.
- Integración API+DB para endpoints principales.

### Semanas 4–5 (Frontend MVP)
- Unit tests de validaciones y mapeos.
- Smoke manual rápido diario contra staging/dev.

### Semana 5 (Integración)
- Enfoque fuerte a pruebas de integración y contratos API.
- Empezar E2E mínimos en staging.

### Semana 6 (QA)
- Regresión completa + E2E críticos.
- Fixes van a Kanban de bugs con prioridad.

### Semana 7 (Deploy)
- Solo correcciones y hardening (cero features nuevas).
- E2E final + smoke + despliegue.

## Infraestructura y Automatización
### Pipeline de CI/CD (GitHub → Cloud Run)
**Qué hace el pipeline actual**
- Push a `develop` → despliega a **Cloud Run Dev** (`c-location-ingest-dev`)
- Push a `main` → despliega a **Cloud Run Prod** (`c-location-ingest`)
- Usa **Workload Identity Federation (OIDC)** (sin llaves JSON) ✅
- Despliega con **Buildpacks** usando `--source` (sin Dockerfile) ✅

**Por qué esto es bueno**
- Elimina manejo de credenciales (seguridad correcta).
- Mantiene el deploy simple y repetible.
- Cloud Run compila y despliega automáticamente.

---

### Pipeline recomendado (CI/CD completo) para el MVP

#### Flujo por rama
- **PR hacia `develop`:** corre CI (lint + unit tests + build). **No despliega**.
- **Merge/Push a `develop`:** despliega a Dev + **smoke tests**.
- **PR hacia `main`:** corre CI + (opcional) integración.
- **Merge a `main`:** despliega a Prod *(ideal con aprobación manual o tag release)*.

---

### YAML (CI + Deploy) 

Se crea archivo: `.github/workflows/cloudrun.yml`

```
name: CI/CD - Cloud Run

on:
  pull_request:
    branches: ["develop", "main"]
  push:
    branches: ["develop", "main"]

env:
  PROJECT_ID: "evocative-reef-133021"
  REGION: "us-central1"

  SERVICE_DEV: "c-location-ingest-dev"
  SERVICE_PROD: "c-location-ingest"

  SERVICE_DIR: "jc-pt-mopt"
  SOURCE_PATH: "services/JC.LocationIngest"

jobs:
  # -------------------------
  # 1) CI - Calidad mínima
  # -------------------------
  ci:
    name: CI (Lint + Tests + Build)
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Ajusta versión según tu proyecto
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "8.0.x"

      - name: Restore
        working-directory: ${{ env.SERVICE_DIR }}/${{ env.SOURCE_PATH }}
        run: dotnet restore

      - name: Build
        working-directory: ${{ env.SERVICE_DIR }}/${{ env.SOURCE_PATH }}
        run: dotnet build -c Release --no-restore

      - name: Unit Tests
        working-directory: ${{ env.SERVICE_DIR }}/${{ env.SOURCE_PATH }}
        run: dotnet test -c Release --no-build --logger "trx"

  # -------------------------
  # 2) Deploy - Solo en push
  # -------------------------
  deploy:
    name: Deploy to Cloud Run
    runs-on: ubuntu-latest
    needs: ci
    if: github.event_name == 'push'
    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Google Auth (Workload Identity Federation)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: "projects/846193025977/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
          service_account: "jc-cloudrun-pt@evocative-reef-133021.iam.gserviceaccount.com"

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2

      - name: Select service by branch
        run: |
          if [ "${GITHUB_REF_NAME}" = "develop" ]; then
            echo "SERVICE=${{ env.SERVICE_DEV }}" >> $GITHUB_ENV
            echo "ENV_NAME=Development" >> $GITHUB_ENV
            echo "ASPNET_ENV=Development" >> $GITHUB_ENV
          else
            echo "SERVICE=${{ env.SERVICE_PROD }}" >> $GITHUB_ENV
            echo "ENV_NAME=Production" >> $GITHUB_ENV
            echo "ASPNET_ENV=Production" >> $GITHUB_ENV
          fi

      - name: Deploy (Buildpacks - no Docker)
        working-directory: ${{ env.SERVICE_DIR }}
        run: |
          gcloud run deploy "${{ env.SERVICE }}" \
            --source "${{ env.SOURCE_PATH }}" \
            --project "${{ env.PROJECT_ID }}" \
            --region "${{ env.REGION }}" \
            --platform managed \
            --allow-unauthenticated \
            --port 8080 \
            --timeout 300 \
            --memory 512Mi \
            --set-env-vars ASPNETCORE_ENVIRONMENT=${{ env.ASPNET_ENV }}

      # -------------------------
      # 3) Smoke test post-deploy
      # -------------------------
      - name: Get service URL
        run: |
          URL=$(gcloud run services describe "${{ env.SERVICE }}" \
            --project "${{ env.PROJECT_ID }}" \
            --region "${{ env.REGION }}" \
            --format='value(status.url)')
          echo "SERVICE_URL=$URL" >> $GITHUB_ENV
          echo "Deployed URL: $URL"

      - name: Smoke Test (health endpoint)
        run: |
          # Cambia /health por tu endpoint real (ej /status o /healthz)
          curl -f "${{ env.SERVICE_URL }}/health"
```
## ✅ Resumen operativo (CI/CD + Observabilidad)

- **CI (Integración continua):** cada PR corre **build + unit tests**. Si falla, **no se mezcla** el cambio.  
- **CD (Despliegue continuo):** merge/push a `develop` despliega a **Dev**; merge a `main` despliega a **Prod**.  
- **Seguridad:** **Workload Identity Federation** (GitHub se autentica **sin llaves**).  
- **Calidad:** siempre pasa por CI antes del deploy y luego se ejecuta **smoke test post-deploy**.

---

## Observabilidad Logs, Errores, Trazas y Métricas

### Logging centralizado para rastreo de un error distribuido.

#### Herramientas GCP que aplican directo
- **Cloud Logging:** logs de Cloud Run (stdout/stderr + logs estructurados).
- **Error Reporting:** agrupa excepciones y muestra “top errors” por servicio/revisión.
- **Cloud Trace:** traza requests end-to-end para ver cuellos de botella y fallos.
- **(Opcional recomendado) OpenTelemetry:** estandariza trace/span y correlación entre servicios.

---

### Estrategia recomendada (efectiva y práctica)

#### 1) Correlación por `correlationId`
- Cada request debe tener un `correlationId`:
  - Si viene por header, se respeta.
  - Si no viene, se genera.
- Ese `correlationId` se incluye en **todos los logs**.
- Así se sigue el hilo: **API → DB → (otros componentes)** con un solo ID.

#### 2) Logs estructurados (JSON)
Loggear en JSON para filtrar rápido por campos:
- `service`, `env`, `revision`, `correlationId`, `user`, `endpoint`, `status`, `durationMs`, `traceId`.

#### 3) Trace + Logs (flujo típico)
1. En **Cloud Logging**, filtro por `severity=ERROR` y/o `correlationId`.
2. Encuentro el log del error → tomo `traceId`/request.
3. Abro **Cloud Trace** → veo dónde falló o dónde se fue el tiempo.
4. Si es recurrente, **Error Reporting** lo agrupa y muestra tendencia.

#### 4) Separación por ambiente
- Incluir siempre `ENV=Development/Production` (ya lo define `ASPNETCORE_ENVIRONMENT`).
- Evita mezclar ruido de dev con producción.

---

## 📊 Métricas: KPIs técnicos recomendados

### Cloud Run (servicio)

**Rendimiento**
- **Latencia:** p50 / p95 / p99 *(la p95 es la que más duele en usuario real)*
- **Throughput:** requests por segundo/minuto
- **Concurrencia:** requests concurrentes por instancia

**Estabilidad**
- **Error rate:** 5xx (servicio) y 4xx (cliente/validación; si suben puede ser bug o contrato roto)
- **Crashes / reinicios:** OOM, errores fatales

**Capacidad**
- CPU y memoria por instancia
- Número de instancias (autoscaling) y picos
- Señales de **cold starts** (picos de latencia + escalado)

---

### Cloud SQL (base de datos)
- **Conexiones activas** (si se disparan, te tumba la app)
- CPU / Memoria
- Latencia de queries
- IO/Disk
- Errores de conexión (timeouts, refused, pool agotado)

---

## 🚨 Alertas recomendadas

En **Cloud Monitoring**:
- Error rate **5xx > X%** por 5–10 min
- Latencia **p95 > umbral** (ej. 800ms–1s según objetivo)
- CPU o Memoria > 80–90% sostenido
- Conexiones Cloud SQL cerca del límite
- Healthcheck fallando / caída total

---

## 🧩 Cuando algo falla

Cuando alguien diga “se cayó inventario” o “No funciona”:
1. Reviso **Error Reporting** (excepción y tendencia).
2. Si tengo `correlationId`, filtro en **Cloud Logging**.
3. Veo endpoint, status, duración y contexto del error.
4. Abro **Cloud Trace** para ubicar el punto exacto de falla/lentitud.
5. Reviso **Cloud Monitoring** para confirmar si fue Cloud Run o Cloud SQL.

# Swagger

<p align="center">
  <img src="https://avatars.githubusercontent.com/u/7658037?s=200&v=4" width="140" alt="Swagger Logo" />
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/assets/swagger.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/swagger.png" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/assets/swagger2.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/assets/swagger2.png" width="720" /></a>>


## 📎 Anexos

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudsqlstudio.jpg"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudsqlstudio.jpg" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun.png" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun2.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun2.png" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun3.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudrun3.png" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudsql.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/cloudsql.png" width="720" /></a>
</p>

<p align="center">
  <a href="https://github.com/jesussv/jc-pt-mopt/blob/main/clouderror.png"><img src="https://github.com/jesussv/jc-pt-mopt/blob/main/clouderror.png" width="720" /></a>
</p>




