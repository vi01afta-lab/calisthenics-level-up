# GitHub Copilot — Instrucciones del Proyecto

> Este archivo define el contexto completo del ecosistema **Calisthenics Level Up**.
> Copilot DEBE leer todo antes de sugerir cualquier código, arquitectura o configuración.

---

## 1. Descripción del Proyecto

**Calisthenics Level Up** es una app Android de calistenia con mecánica de RPG.
El desarrollador (`vi01afta-lab`) trabaja en una planta termoeléctrica con señal
intermitente — la app es **Offline-First de forma obligatoria**.

### Restricción absoluta: costo de infraestructura = CERO
Todo debe correr en niveles gratuitos permanentes (Firebase Free Tier, GitHub Free,
Google AI Free Tier). Ninguna propuesta que genere costo mensual es aceptable.

### Stack tecnológico
| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter / Dart |
| Backend | Firebase Firestore + Google Apps Script |
| Storage | Firebase Storage + Google Drive |
| CI/CD | GitHub Actions |
| Orquestación IA | n8n (instancia cloud: `https://vigilago.app.n8n.cloud`) |
| Modelo IA | Google Gemini `gemini-3.1-flash-lite` (Free Tier) |

---

## 2. Reglas de Negocio del Motor RPG

Estos valores son inmutables y ya están implementados en el pipeline de agentes:

```
XP por sesión = 100 × nivel^1.5
Cooldown      = (series × reps × multiplicador) / factor_recuperacion
                → mínimo: 12 horas | máximo: 72 horas
Anti-Penalty  = si no hay sesión registrada, el nivel NO baja
```

### Estructura de Firestore
```
history_{YYYY_MM}/          ← particionado por mes
  {sessionId}/
    level: number
    xp: number
    muscle_groups: string[]
    timestamp: ISO-8601
```

---

## 3. Ecosistema n8n — CONTEXTO CRÍTICO

### 3.1 Qué es n8n en este proyecto
n8n actúa como el "sistema nervioso" del proyecto. Orquesta los 5 agentes IA y el
pipeline CI/CD. **No es solo un automatizador — es la infraestructura de desarrollo.**

### 3.2 Limitaciones del runtime de n8n que Copilot DEBE conocer

#### Nodo Code (JavaScript sandbox)
```
❌ NO disponible:
   - credentials.*              (no hay acceso a credenciales desde código)
   - fetch()                    (no confiable — usar nodos HTTP Request)
   - require('fs')              (sin acceso a filesystem)
   - ls, shell commands         (sin ejecución de comandos)
   - $getWorkflowStaticData()   (prohibido — estado via cable JSON únicamente)

✅ SÍ disponible:
   - require('crypto')          (built-in de Node.js)
   - require('Buffer')          (built-in de Node.js)
   - $json                      (datos del item actual)
   - $input.first().json        (primer item del input)
   - $input.all()               (todos los items)
   - $node['NombreNodo'].json   (output de nodo específico)
   - $workflow.id               (ID del workflow actual)
```

#### Para llamadas HTTP autenticadas
```
✅ CORRECTO: Usar nodo "HTTP Request" con credencial configurada en n8n
❌ INCORRECTO: fetch(url, { headers: { Authorization: `token ${credentials.github.token}` } })
```

#### Para obtener árbol de archivos de un repositorio GitHub
```
✅ CORRECTO: GET https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1
❌ INCORRECTO: ls -R (no existe en sandbox)
❌ INCORRECTO: require('fs').readdirSync() (no existe en sandbox)
```

#### Para crear/actualizar archivos en GitHub
```
✅ CORRECTO: PUT /repos/{owner}/{repo}/contents/{path}
             con sha: (obtenido de GET /contents/{path} previo — SIEMPRE necesario)
❌ INCORRECTO: Omitir el sha → GitHub responde 422 inmediatamente
```

#### Para state management entre nodos
```
✅ CORRECTO: JSON que viaja por cable entre nodos
❌ INCORRECTO: $getWorkflowStaticData('global') — prohibido por directiva arquitectural
```

### 3.3 Credenciales en n8n
| Servicio | Tipo en n8n | ID |
|----------|------------|-----|
| GitHub | GitHub API (PAT) | `qmWndu5nSXhYs1qx` |
| Google Gemini | Google Palm API | (configurada en agentes) |

**Las credenciales NUNCA se referencian desde un nodo Code. Solo desde nodos nativos
de n8n (HTTP Request, GitHub, etc.) mediante el selector de credenciales de la UI.**

---

## 4. Los 5 Agentes IA

Todos usan **Chat Trigger privado** (no tienen URL de webhook pública).
**No existe mecanismo para dispararlos programáticamente desde otro workflow.**
Son conversacionales — solo responden a mensajes enviados manualmente en el editor.

| Agente | Workflow ID | Especialidad |
|--------|-------------|-------------|
| Backend Senior | `8LteBQa5ziuQqHwX` | Firebase, Firestore Rules, Apps Script |
| Frontend Senior | `eT4q7gUjTEUnVKUS` | Flutter/Dart, UI/UX, animaciones |
| Tech Lead & PM | `XVc3D7V350p0F7Ak` | Arquitectura, decisiones de diseño |
| Red Team QA | `lsECmpvkuCSVz5DV` | Auditoría adversarial (no escribe código) |
| Blue Team Refactoring | `g3xKJiHWg5AhseWP` | Refactoriza según hallazgos del Red Team |

**El "Tech Lead" es un agente IA, no un humano.** Cualquier "escalada al Tech Lead"
en el contexto de este proyecto significa comunicación manual — no un trigger
programático.

Modelo de todos los agentes: `gemini-3.1-flash-lite`
Cuota diaria: limitada (Free Tier). Cada llamada innecesaria agota la cuota del día.

---

## 5. Pipeline CI/CD Orquestador

**Workflow ID:** `nBAwgJADvMTdSMYK`
**Trigger:** Form Trigger en `https://vigilago.app.n8n.cloud/form/pipeline-cicd`

### Campos de entrada del formulario
```
fase          : número de fase de desarrollo (1, 2, 3...)
tarea_backend : descripción para el agente Backend Senior
tarea_frontend: descripción para el agente Frontend Senior
```

### Flujo interno
```
Formulario → Inicializar Estado JSON → Loop (máx 3 iteraciones)
  → Backend Senior Agent (paralelo) + Frontend Senior Agent (paralelo)
  → Combinar resultados
  → Red Team QA
  → Blue Team Refactoring
  → Tech Lead Review
  → ¿Aprobado? → SÍ: Extraer Archivos → Commit GitHub
              → NO: siguiente iteración
```

### Estado: viaja exclusivamente por cable JSON
```javascript
// CORRECTO
return [{ json: { iter: state.iter + 1, aprobado: false, ... } }];

// INCORRECTO
const sd = $getWorkflowStaticData('global'); // PROHIBIDO
```

---

## 6. Protocolo Camaleón — Formato de Output de los Agentes

Los agentes IA deben envolver su output en marcadores específicos.
El nodo "Extraer Archivos" del pipeline usa regex para parsear estos marcadores.

| Archivo destino | Marcador inicio | Marcador fin |
|----------------|-----------------|-------------|
| `lib/main.dart` | ` ```dart ` | ` ``` ` |
| `firestore.rules` | `###START_RULES###` | `###END_RULES###` |
| `.github/workflows/*.yml` | `###START_WORKFLOW###` | `###END_WORKFLOW###` |
| `pubspec.yaml` | `###START_PUBSPEC###` | `###END_PUBSPEC###` |
| `build.gradle` | `###START_GRADLE###` | `###END_GRADLE###` |

**Regla:** Ningún sistema debe generar JSON libre `{"fileName": ..., "content": ...}`.
Todo output de código pasa por marcadores del Protocolo Camaleón.

**Si se agrega un nuevo tipo de archivo al sistema, el nodo "Extraer Archivos"
del pipeline debe ser modificado para incluir la nueva regex. No es automático.**

---

## 7. Dominio de Archivos — Contrato Inmutable

Dos sistemas distintos NO pueden escribir en los mismos archivos.
Violar esto produce corrupción silenciosa garantizada (dos commits independientes
sobre el mismo archivo sin coordinación).

| Sistema | Puede escribir | Prohibido absoluto |
|---------|---------------|--------------------|
| Pipeline CI/CD (`nBAwgJADvMTdSMYK`) | `lib/main.dart`, `firestore.rules` | Todo lo demás |
| Auto-Reparador (workflow a construir) | `.github/workflows/*.yml`, `pubspec.yaml`, `build.gradle` | `lib/main.dart`, `firestore.rules` |

**Si el Auto-Reparador detecta que el error está en `lib/main.dart` o
`firestore.rules`, DEBE notificar y detenerse. No intentar reparar.**

---

## 8. Reglas de Commits a GitHub desde n8n

### Update de archivo existente (PUT /contents/{path})
```json
{
  "message": "Descripción del commit [skip ci]",
  "content": "<base64 del contenido>",
  "sha": "<SHA actual del archivo — obtenido con GET /contents/{path} previo>",
  "branch": "main",
  "committer": {
    "name": "n8n Auto-Repair",
    "email": "noreply@n8n.local"
  }
}
```

El campo `sha` es SIEMPRE obligatorio para archivos existentes.
Sin él, GitHub responde 422. No hay excepciones.

### `[skip ci]` — cuándo usarlo
Todos los commits generados por sistemas automáticos (pipeline, auto-reparador)
deben incluir `[skip ci]` en el mensaje de commit **a menos que el propósito
sea verificar que GitHub Actions pase** (como en el auto-reparador después de
aplicar una corrección). Los commits de rollback SIEMPRE llevan `[skip ci]`.

### Rama `main`
Sin branch protection. Los commits directos funcionan.
GitHub credential ID en n8n: `qmWndu5nSXhYs1qx`.

---

## 9. Auto-Reparador — Diseño Aprobado (workflow pendiente de construir)

### Responsabilidad única
Detecta fallos en GitHub Actions y repara SOLO archivos de infraestructura CI/CD.

### Trigger
Webhook de GitHub evento `workflow_run` filtrado por `conclusion == 'failure'`.
URL de destino: `https://vigilago.app.n8n.cloud/webhook/github-auto-repair`

### Seguridad: HMAC-SHA256 obligatorio
Verificar la firma `X-Hub-Signature-256` en el primer nodo post-webhook.
Sin verificación, cualquier actor puede disparar commits automáticos.

### Cómo obtener el error log real
El webhook de `workflow_run` NO contiene el log. Requiere 2 llamadas adicionales:
```
1. GET /repos/vi01afta-lab/calisthenics-level-up/actions/runs/{run_id}/jobs
   → extrae jobs[0].id

2. GET /repos/vi01afta-lab/calisthenics-level-up/actions/jobs/{job_id}/logs
   → devuelve texto plano (puede ser largo — truncar a últimas 200 líneas)
```

### Cómo obtener el último commit exitoso real
```
GET /repos/vi01afta-lab/calisthenics-level-up/actions/runs
    ?status=success&per_page=1&workflow_id={originalWorkflowId}
```
- `status=success` filtra por conclusión exitosa (no solo "completado")
- `workflow_id` debe ser el mismo workflow que falló (del webhook: `workflow_run.workflow_id`)
- Si no hay runs exitosos: notificar y detener — un punto seguro al que revertir no existe

### Rollback correcto (revert commits, no force-push)
Para cada SHA en `attemptShas[]` en orden inverso (último primero):
```
1. GET /git/commits/{SHA_a_revertir}
   → parentSha = response.parents[0].sha

2. GET /git/commits/{parentSha}
   → parentTreeSha = response.tree.sha    ← árbol del PADRE, no del commit fallido

3. POST /git/commits
   { message: "Revert auto-repair [skip ci]", tree: parentTreeSha, parents: [current_main_sha] }
   → revertCommitSha = response.sha

4. PATCH /git/refs/heads/main
   { sha: revertCommitSha }
```

Force-push (`PATCH` con `force: true`) NO es aceptable porque:
- Reescribe historial de forma agresiva
- No permite incluir `[skip ci]` → dispara GitHub Actions nuevamente en bucle

### Límites del sistema
```
maxRepairAttempts : 2    (inicializar repairAttempt en 0, condición: >= maxAttempts)
maxPollAttempts   : 10 × 60s = 10 minutos total
maxFormatRetries  : 2    (intentos de reformateo de output del AI, por intento de reparación)
```

### Polling determinista
```
GET /actions/runs?head_sha={newCommitSha}&workflow_id={originalWorkflowId}
```
Filtrar por `workflow_id` es obligatorio. Sin él, un workflow de `lint` exitoso
puede hacer que el sistema declare victoria mientras `deploy` sigue fallando.

### JSON de estado (estructura aprobada)
```json
{
  "webhook": {
    "workflowRunId": 12345,
    "workflowId": "12345678",
    "workflowFileName": "deploy.yml",
    "currentFailedSha": "abc123...",
    "failedBranch": "main"
  },
  "recovery": {
    "lastSuccessfulSha": "xyz789...",
    "repairAttempt": 0,
    "maxRepairAttempts": 2,
    "attemptShas": [],
    "pollAttempt": 0,
    "maxPollAttempts": 10,
    "formatRetryAttempt": 0,
    "maxFormatRetries": 2
  },
  "context": {
    "errorLog": "[últimas 200 líneas del log en texto plano]",
    "jobId": 67890,
    "fileTree": [".github/workflows/deploy.yml", "pubspec.yaml", "..."],
    "previousAttemptCode": null,
    "previousFailureReason": null
  },
  "timing": {
    "webhookReceivedAt": "2026-07-08T14:30:00Z"
  }
}
```

---

## 10. Reglas para Propuestas de Copilot

### Al proponer el código para los nodos n8n
- Nunca usar `fetch()` — siempre nodos HTTP Request
- Nunca usar `credentials.*` — las credenciales se configuran en la UI de n8n
- Nunca usar `$getWorkflowStaticData` — estado via JSON por cable
- Nunca proponer `ls`, `readFile`, o cualquier operación de filesystem
- Al proponer JavaScript para nodo Code, limitarse a lo disponible en el sandbox

### Al proponer commits a GitHub desde n8n
- Siempre obtener el SHA actual del archivo antes de un PUT
- Siempre incluir `[skip ci]` en commits de rollback
- Usar el nodo GitHub de n8n (con credencial `qmWndu5nSXhYs1qx`) cuando sea posible

### Al proponer lógica de auto-reparación
- Nunca tocar `lib/main.dart` ni `firestore.rules`
- El error log viene de la API de Jobs, no del webhook
- `lastSuccessfulSha` debe filtrarse por `workflow_id` del run que falló
- El rollback usa el árbol del **padre** del commit a revertir, no del commit mismo

### Al proponer escaladas
- El "Tech Lead" es un agente IA sin webhook — no se puede disparar programáticamente
- La escalada en Fase 1 es: notificación Telegram al usuario + fin del flujo
- El pipeline CI/CD (`nBAwgJADvMTdSMYK`) es SOLO para features de la app, no para debugging de CI/CD

### Al proponer arquitectura multi-agente
- Los 5 agentes tienen Chat Trigger privado — un mecanismo para dispararlos programáticamente no existe
- Crear un 6º agente DevOps es Fase 2 (pendiente) —!no asumir que existe

---

## 11. Repositorio
```
Owner   : vi01afta-lab
Repo    : calisthenics-level-up
Rama    : main (sin branch protection — commits directos funcionan)
```

### Archivos con dominio asignado
```
lib/main.dart              → Pipeline CI/CD (Frontend Senior Agent)
firestore.rules            → Pipeline CI/CD (Backend Senior Agent)
.github/workflows/*.yml   → Auto-Reparador
pubspec.yaml               → Auto-Reparador
build.gradle               → Auto-Reparador
```

---

## 12. Fases de Desarrollo de la App

El proyecto sigue un plan de 8 fases. Las primeras 3 son:

| Fase | Componente | Estado |
|------|-----------|--------|
| 1 | Motor RPG (XP + Cooldown + Muscle Map SVG) | En progreso |
| 2 | Dashboard + Tabata Timer | Pendiente |
| 3 | Galería de Evolución + Registro de Sesión | Pendiente |

---

*Última actualización: 2026-07-08*
*Mantenido por: n8n Instance Agent + vi01afta-lab*
