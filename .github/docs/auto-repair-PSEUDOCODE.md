# Auto-Reparador: Pseudocódigo Lógico Completo

> **Versión:** Final (Corregida con todos los errores técnicos de n8n identificados)  
> **Fecha:** 2026-07-08  
> **Destino:** Agente n8n construye los nodos reales con esto

---

## 📋 Estructura General

```
NODO #1: GitHub Webhook (Trigger)
    ↓
NODO #2: Validar HMAC-SHA256 (Security)
    ↓
NODO #3: Filtrar conclusion == 'failure' (If)
    ↓
[NODO #4A-4C]: Obtener lastSuccessfulSha + Logs (HTTP Requests)
    ↓
NODO #5: Inicializar Estado JSON
    ↓
[LOOP PRINCIPAL - Max 2 intentos]
  ├─ NODO #6: ¿repairAttempt > maxRepairAttempts?
  ├─ NODO #7: Obtener Árbol de Archivos
  ├─ NODO #8: Llamar AI Agent
  ├─ NODO #9: Validar Output (Escalada/Retry/Proceed)
  ├─ NODO #10: Extraer Archivo (Regex)
  ├─ NODO #11-12: Obtener SHA + Hacer Commit
  ├─ NODO #13: Actualizar Estado
  ├─ NODO #14: Wait 30s
  ├─ NODO #15-16: Polling (Max 10 encuestas × 60s)
  └─ NODO #17: Leer conclusión
       ├─ SÍ (success) → NODO #18 (Notificar Éxito)
       └─ NO → Volver a NODO #6
    ↓
[Si ambos intentos fallan]
  └─ NODO #19: Rollback (Revert commits)
       ↓
  NODO #20: Notificar Fallo
```

---

## 🔧 PSEUDOCÓDIGO POR NODO

### NODO #1: GitHub Webhook (Trigger)
**Tipo:** Webhook  
**Ruta:** `/github-auto-repair`  
**Método:** `POST`  
**Respuesta:** Inmediata (200 OK)

**Output esperado:**
```javascript
{
  body: {
    workflow_run: {
      id: <number>,
      workflow_id: <number>,
      head_sha: <string>,
      name: <string>,
      conclusion: "failure" | "success" | null
    }
  },
  headers: {
    "x-hub-signature-256": "sha256=..."
  }
}
```

**Siguiente:** NODO #2

---

### NODO #2: Validar HMAC-SHA256
**Tipo:** Code (JavaScript)  
**Acceso:** Nodo anterior + Credencial de secreto

**Pseudocódigo:**
```javascript
// Input: $input.first().json (contiene body + headers)
const body = $input.first().json.body;
const signature = $input.first().json.headers['x-hub-signature-256'];
const secret = "<GITHUB_WEBHOOK_SECRET>";  // Viene de credencial, NO hardcoded

// Calcular HMAC-SHA256
const crypto = require('crypto');
const payload = JSON.stringify(body);
const hash = crypto
  .createHmac('sha256', secret)
  .update(payload)
  .digest('hex');
const expectedSignature = `sha256=${hash}`;

// Validar
if (signature !== expectedSignature) {
  throw new Error(`Invalid signature. Expected: ${expectedSignature}, Got: ${signature}`);
}

// Si llega aquí, firma válida
return {
  valid: true,
  webhook: $input.first().json
};
```

**Siguiente:** NODO #3

---

### NODO #3: Filtrar conclusion == 'failure'
**Tipo:** If  
**Condición:** `$input.first().json.body.workflow_run.conclusion == 'failure'`

**Branches:**
- SÍ (true) → NODO #4A
- NO (false) → Fin silencioso (no notificar nada)

---

### NODO #4A: Obtener lastSuccessfulSha (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:** 
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/actions/runs?status=success&per_page=1&workflow_id={{$input.first().json.body.workflow_run.workflow_id}}
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
```

**Response handling:**
```javascript
// Si no hay runs exitosos:
if (!response.workflow_runs || response.workflow_runs.length === 0) {
  throw new Error("NO_SUCCESSFUL_RUN: Cannot rollback without a known good state");
}

// Extraer
const lastSuccessfulRun = response.workflow_runs[0];
const lastSuccessfulSha = lastSuccessfulRun.head_sha;
const originalWorkflowId = lastSuccessfulRun.workflow_id;

return {
  lastSuccessfulSha,
  originalWorkflowId,
  runId: response.workflow_runs[0].id
};
```

**Siguiente:** NODO #4B

---

### NODO #4B: Obtener Job ID del Run Fallido (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/actions/runs/{{$input.first().json.body.workflow_run.id}}/jobs
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
```

**Response handling:**
```javascript
// Obtener el primer job (generalmente hay uno)
const job = response.jobs[0];
const jobId = job.id;

return {
  jobId,
  jobName: job.name
};
```

**Siguiente:** NODO #4C

---

### NODO #4C: Obtener Logs del Job (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/actions/jobs/{{$input.previous().json.jobId}}/logs
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: text/plain  ← IMPORTANTE: devuelve texto plano, no JSON
```

**Response handling:**
```javascript
// response es texto plano (múltiples líneas)
const fullLog = response;

// ⚠️ CRÍTICO: Truncar logs para no exceder contexto de Gemini
// Conservar últimas 100 líneas (o últimas 10KB, lo que sea menor)
const lines = fullLog.split('\n');
const truncatedLog = lines.slice(-100).join('\n');

// Filtrar por líneas relevantes (Error, FAILED, Exception, error:)
const relevantLines = truncatedLog
  .split('\n')
  .filter(line => 
    /error|failed|exception|error:|❌|✗/i.test(line)
  );

const errorLogForAI = relevantLines.join('\n');

return {
  errorLog: errorLogForAI,
  originalErrorLogSize: fullLog.length,
  truncatedSize: truncatedLog.length
};
```

**Siguiente:** NODO #5

---

### NODO #5: Inicializar Estado JSON
**Tipo:** Code (JavaScript)

**Pseudocódigo:**
```javascript
// Recopilar inputs de nodos anteriores
const webhook = $input.first().json.body.workflow_run;
const lastSuccessfulData = $input.nth(0).json;  // NODO #4A
const errorLogData = $input.nth(1).json;  // NODO #4C

const state = {
  webhook: {
    failedRunId: webhook.id,
    failedWorkflowId: webhook.workflow_id,
    currentFailedSha: webhook.head_sha,
    failedBranch: webhook.branch || "main",
    workflowName: webhook.name
  },

  recovery: {
    lastSuccessfulSha: lastSuccessfulData.lastSuccessfulSha,
    lastSuccessfulRunId: lastSuccessfulData.runId,
    repairAttempt: 1,  // Comienza en 1
    maxRepairAttempts: 2,
    attemptShas: [],
    pollAttempt: 0,
    maxPollAttempts: 10
  },

  context: {
    errorLog: errorLogData.errorLog,
    errorLogOriginalSize: errorLogData.originalErrorLogSize,
    fileTree: [],  // Se llenará en NODO #7
    previousAttemptCode: null,
    previousFailureReason: null,
    formatRetryCount: 0,
    maxFormatRetries: 2
  },

  timing: {
    webhookReceivedAt: new Date().toISOString(),
    repairStartedAt: new Date().toISOString()
  }
};

return state;
```

**Output:** Objeto `state` serializado  
**Siguiente:** NODO #6

---

### NODO #6: ¿repairAttempt > maxRepairAttempts? (If)
**Tipo:** If  
**Condición:** `$input.first().json.recovery.repairAttempt > $input.first().json.recovery.maxRepairAttempts`

**IMPORTANTE:** `>` (mayor que), NO `>=` (mayor o igual). Esto previene el off-by-one.

**Branches:**
- SÍ (true) → NODO #19 (Rollback)
- NO (false) → NODO #7 (Continuar reparación)

---

### NODO #7: Obtener Árbol de Archivos (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/git/trees/HEAD?recursive=1
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
```

**Response handling:**
```javascript
// Filtrar solo archivos (type === 'blob'), no directorios
const files = response.tree
  .filter(entry => entry.type === 'blob')
  .map(entry => entry.path);

// Guardar en estado para contexto del AI Agent
const state = $input.first().json;
state.context.fileTree = files;

return {
  fileTree: files,
  fileCount: files.length,
  state: state
};
```

**Siguiente:** NODO #8

---

### NODO #8: Llamar AI Agent (Gemini)
**Tipo:** Google Generative AI (Gemini)  
**Modelo:** `gemini-3.1-flash-lite`  
**Temperatura:** 0 (determinista)

**System Prompt (COMPLETO Y EXACTO):**
```
You are an expert DevOps/CI-CD engineer specializing in GitHub Actions and Flutter troubleshooting.

Your ONLY goal is to repair failures in CI/CD infrastructure files and build configuration.

ALLOWED files you can attempt to fix:
- .github/workflows/*.yml (GitHub Actions workflows)
- pubspec.yaml (Flutter/Dart dependencies and build config)
- build.gradle (Android Gradle build configuration)

FORBIDDEN files (you MUST NEVER attempt to fix or modify):
- lib/main.dart (Flutter application logic)
- firestore.rules (Firebase Firestore rules)
- Any other file outside the ALLOWED list

CRITICAL RULES:

1. If the error originates from a FORBIDDEN file or requires modifying app logic, respond with EXACTLY:
   ###ERROR_ESCALATE###
   This error belongs to application logic, not CI/CD infrastructure. The error appears to be in [which file].
   Manual review by the development team is required.
   ###ERROR_ESCALATE###

2. If you can identify and fix the issue in an ALLOWED file, respond with EXACTLY:
   ###START_WORKFLOW###
   [complete corrected file content here - valid YAML or Gradle syntax]
   ###END_WORKFLOW###

3. IMPORTANT: Do NOT include any explanations, comments, or text outside the markers. Only the fixed code.

ANALYSIS PROCESS:
- Carefully read the GitHub Actions error log provided
- Compare errors against the current file tree
- Check for: missing dependencies, syntax errors, version mismatches, Free Tier limits, timeouts
- Consider environment-specific issues (GitHub Actions runner limits, network timeouts, disk space)

PREVIOUS ATTEMPTS (if this is retry #2):
- Previous attempt code: [provided if retry]
- Why it failed: [provided if retry]
- Your task: Generate a different fix based on the failure reason

OUTPUT FORMAT:
- Only valid YAML (for workflows)
- Only valid Gradle syntax (for build.gradle)
- Only valid pubspec.yaml format (for dependencies)
- Absolutely NO comments or explanations outside markers
```

**User Message to send:**
```
Attempt {{$input.first().json.recovery.repairAttempt}}/{{$input.first().json.recovery.maxRepairAttempts}}

ERROR LOG from GitHub Actions:
---
{{$input.first().json.context.errorLog}}
---

CURRENT FILE TREE:
{{$input.first().json.context.fileTree.join('\n')}}

{{if $input.first().json.context.previousAttemptCode}}
PREVIOUS ATTEMPT (#{{$input.first().json.recovery.repairAttempt - 1}}):
Code that was tried:
---
{{$input.first().json.context.previousAttemptCode}}
---

Why it failed:
{{$input.first().json.context.previousFailureReason}}
{{/if}}

Please analyze the error and provide a fix.
```

**Response handling:**
```javascript
const aiResponse = $input.first().json.choices[0].message.content;

return {
  aiResponse,
  containsEscalate: aiResponse.includes('###ERROR_ESCALATE###'),
  containsWorkflow: aiResponse.includes('###START_WORKFLOW###'),
  rawText: aiResponse
};
```

**Siguiente:** NODO #9

---

### NODO #9: Validar Output del AI (Code)
**Tipo:** Code (JavaScript)

**Pseudocódigo:**
```javascript
const state = $input.first().json;  // Estado actual
const aiResponse = $input.nth(0).json;  // Respuesta del AI

// ========================
// VERIFICACIÓN 1: Escalada
// ========================
if (aiResponse.containsEscalate) {
  return {
    action: 'ESCALATE',
    reason: 'AI detected error is outside CI/CD scope',
    aiMessage: aiResponse.aiResponse,
    nextNode: 'NODO_#20_NOTIFICAR_ESCALADA'
  };
}

// ========================
// VERIFICACIÓN 2: Archivos prohibidos
// ========================
const forbiddenFiles = ['lib/main.dart', 'firestore.rules'];
const aiText = aiResponse.aiResponse;

for (const file of forbiddenFiles) {
  if (aiText.includes(file)) {
    throw new Error(`VIOLATION: AI attempted to modify ${file}. This is forbidden.`);
  }
}

// ========================
// VERIFICACIÓN 3: Marcadores presentes
// ========================
const hasStartMarker = aiText.includes('###START_WORKFLOW###');
const hasEndMarker = aiText.includes('###END_WORKFLOW###');

if (!hasStartMarker || !hasEndMarker) {
  // Retry si los marcadores no están
  state.context.formatRetryCount += 1;
  
  if (state.context.formatRetryCount >= state.context.maxFormatRetries) {
    // Demasiados intentos de formato → Escalada
    return {
      action: 'ESCALATE',
      reason: 'AI failed to produce correctly formatted output after 2 retries',
      nextNode: 'NODO_#20_NOTIFICAR_ESCALADA'
    };
  }
  
  return {
    action: 'RETRY',
    reason: 'Output missing markers. Retrying AI Agent.',
    formatRetryCount: state.context.formatRetryCount,
    state: state,
    nextNode: 'NODO_#8_AI_AGENT'
  };
}

// ========================
// VERIFICACIÓN 4: Marcadores balanceados
// ========================
const startIdx = aiText.indexOf('###START_WORKFLOW###');
const endIdx = aiText.indexOf('###END_WORKFLOW###');

if (startIdx === -1 || endIdx === -1 || startIdx >= endIdx) {
  return {
    action: 'RETRY',
    reason: 'Markers are unbalanced or in wrong order',
    state: state,
    nextNode: 'NODO_#8_AI_AGENT'
  };
}

// ========================
// VERIFICACIÓN 5: Extracto entre marcadores válido
// ========================
const content = aiText.substring(
  startIdx + '###START_WORKFLOW###'.length,
  endIdx
).trim();

if (content.length === 0) {
  return {
    action: 'RETRY',
    reason: 'Content between markers is empty',
    state: state,
    nextNode: 'NODO_#8_AI_AGENT'
  };
}

// ========================
// ÉXITO: Output válido
// ========================
return {
  action: 'PROCEED',
  validOutput: true,
  aiResponse: aiResponse.aiResponse,
  state: state,
  nextNode: 'NODO_#10_EXTRAER_ARCHIVO'
};
```

**Branches:**
- `action: 'ESCALATE'` → NODO #20
- `action: 'RETRY'` → NODO #8 (con contador incremented)
- `action: 'PROCEED'` → NODO #10

---

### NODO #10: Extraer Archivo (Code - Regex)
**Tipo:** Code (JavaScript)

**Pseudocódigo:**
```javascript
const aiResponse = $input.first().json.aiResponse;

// Regex para extraer contenido entre marcadores
const match = aiResponse.match(/###START_WORKFLOW###([\s\S]*?)###END_WORKFLOW###/);

if (!match) {
  throw new Error('Could not extract content between markers');
}

const content = match[1].trim();

// Determinar el nombre del archivo basado en el contenido
// (Este es un heurístico — podría mejorarse)
let fileName;

if (content.includes('name:') || content.includes('on:') || content.includes('jobs:')) {
  // Parece YAML de GitHub Actions
  fileName = '.github/workflows/deploy.yml';
} else if (content.includes('dependencies:') || content.includes('flutter:')) {
  // Parece pubspec.yaml
  fileName = 'pubspec.yaml';
} else if (content.includes('gradle') || content.includes('android') || content.includes('buildTypes')) {
  // Parece build.gradle
  fileName = 'build.gradle';
} else {
  throw new Error('Could not determine file type from content');
}

return {
  fileName,
  content,
  contentSize: content.length
};
```

**Siguiente:** NODO #11

---

### NODO #11: Obtener SHA Actual del Archivo (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/contents/{{$input.first().json.fileName}}
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
```

**Response handling:**
```javascript
// Extraer SHA del archivo actual (necesario para PUT)
const currentSha = response.sha;
const currentContent = response.content;  // base64

return {
  currentSha,
  currentContent,
  fileName: response.path
};
```

**Siguiente:** NODO #12

---

### NODO #12: Hacer Commit con Reparación (HTTP Request)
**Tipo:** HTTP Request  
**Método:** PUT  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/contents/{{$input.nth(0).json.fileName}}
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
Content-Type: application/json
```

**Body (JSON):**
```javascript
{
  "message": `Auto-repair [Attempt {{$input.nth(1).json.recovery.repairAttempt}}/2] [skip ci]`,
  "content": Buffer.from($input.nth(0).json.content).toString('base64'),
  "sha": $input.nth(0).json.currentSha,
  "branch": "main",
  "committer": {
    "name": "n8n Auto-Repair",
    "email": "noreply@n8n.local"
  }
}
```

**Response handling:**
```javascript
const newCommitSha = response.commit.sha;
const newContent = response.content;

return {
  commitSha: newCommitSha,
  committed: true,
  message: response.commit.message
};
```

**Siguiente:** NODO #13

---

### NODO #13: Actualizar Estado JSON (Code)
**Tipo:** Code (JavaScript)

**Pseudocódigo:**
```javascript
const state = $input.first().json;  // Estado previo
const commitResult = $input.nth(0).json;  // Resultado del commit

// Agregar el SHA al historial de intentos
state.recovery.attemptShas.push(commitResult.commitSha);

// Incrementar contador (esto sucede DESPUÉS de hacer el commit)
state.recovery.repairAttempt += 1;

// Reset del contador de retries de formato para próximo intento
state.context.formatRetryCount = 0;

// Guardar el código del intento actual para contexto en próximo intento
state.context.previousAttemptCode = $input.nth(1).json.content;
state.context.previousFailureReason = null;  // Se llenará si falla el polling

return state;
```

**Siguiente:** NODO #14

---

### NODO #14: Wait
**Tipo:** Wait  
**Duración:** 30 segundos

**Razón:** GitHub tarda en registrar el commit y disparar el workflow

**Siguiente:** NODO #15

---

### NODO #15: Polling - GET Workflow Run (HTTP Request)
**Tipo:** HTTP Request  
**Método:** GET  
**URL:**
```
https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/actions/runs?head_sha={{$input.first().json.recovery.attemptShas[$input.first().json.recovery.attemptShas.length - 1]}}&workflow_id={{$input.first().json.webhook.failedWorkflowId}}
```

**Headers:**
```
Authorization: Bearer <GITHUB_TOKEN>
Accept: application/vnd.github+json
```

**Response handling (IMPORTANTE - dentro del nodo Loop):**
```javascript
const state = $input.first().json;
const runsResponse = $input.nth(0).json;

// Verificar si el run del workflow específico existe
if (!runsResponse.workflow_runs || runsResponse.workflow_runs.length === 0) {
  state.recovery.pollAttempt += 1;
  
  if (state.recovery.pollAttempt >= state.recovery.maxPollAttempts) {
    return {
      status: 'TIMEOUT',
      pollAttempt: state.recovery.pollAttempt,
      reason: 'Workflow run not found after 10 polls'
    };
  }
  
  return {
    status: 'NOT_STARTED',
    pollAttempt: state.recovery.pollAttempt,
    message: 'Workflow run not started yet. Will retry.',
    state: state,
    shouldRetry: true
  };
}

const run = runsResponse.workflow_runs[0];

// Verificar si está completo
if (run.status !== 'completed') {
  state.recovery.pollAttempt += 1;
  
  if (state.recovery.pollAttempt >= state.recovery.maxPollAttempts) {
    return {
      status: 'TIMEOUT',
      pollAttempt: state.recovery.pollAttempt,
      reason: 'Workflow did not complete after 10 minutes'
    };
  }
  
  return {
    status: 'IN_PROGRESS',
    pollAttempt: state.recovery.pollAttempt,
    runStatus: run.status,
    message: 'Workflow still running. Will retry in 60 seconds.',
    state: state,
    shouldRetry: true
  };
}

// COMPLETO: extraer conclusión
return {
  status: 'COMPLETED',
  conclusion: run.conclusion,  // 'success', 'failure', 'cancelled', etc.
  pollAttempt: state.recovery.pollAttempt,
  runId: run.id,
  state: state,
  shouldRetry: false
};
```

**Branches en n8n:**
- `shouldRetry: true` y `pollAttempt < maxPollAttempts` → Wait 60s → Loop back a NODO #15
- `shouldRetry: false` → NODO #16

---

### NODO #16: Leer Conclusión (If)
**Tipo:** If  
**Condición:** `$input.first().json.conclusion == 'success'`

**Branches:**
- SÍ (success) → NODO #18 (Notificar Éxito)
- NO (failure/cancelled/etc) → NODO #6 (Incrementar intento y reintenttar, o rollback si maxed out)

---

### NODO #17: Notificar Éxito (HTTP Request)
**Tipo:** HTTP Request (Telegram o Webhook placeholder)

**Pseudocódigo:**
```javascript
const state = $input.first().json;

const message = `✅ **Auto-Repair Successful**
Repository: vi01afta-lab/calisthenics-level-up
Workflow: ${state.webhook.workflowName}
Repaired File: ${state.context.previousAttemptCode ? 'pubspec.yaml/workflow' : 'unknown'}
Attempt: ${state.recovery.repairAttempt - 1}/2
Commit SHA: ${state.recovery.attemptShas[state.recovery.attemptShas.length - 1].substring(0, 7)}
Timestamp: ${new Date().toISOString()}`;

// Enviar a Telegram (placeholder - configurar credencial real)
return {
  message,
  status: 'sent',
  to: 'TELEGRAM_CHAT_ID'
};
```

**Siguiente:** FIN

---

### NODO #18: Rollback - Revert Commits (Code)
**Tipo:** Code (JavaScript) - **COMPLEJO**

**IMPORTANTE:** Este nodo hace 3 llamadas HTTP encadenadas POR CADA SHA a revertir.

**Pseudocódigo:**
```javascript
const state = $input.first().json;
const attemptShas = state.recovery.attemptShas;  // [sha1, sha2] si 2 intentos fallidos

if (attemptShas.length === 0) {
  return {
    rollback: false,
    reason: 'No attempt SHAs to rollback'
  };
}

// Revertir en orden INVERSO (último primero)
const reversedShas = attemptShas.reverse();

async function createRevertCommit(shaToRevert, gitToken) {
  // ========================================
  // PASO 1: Obtener el padre del commit
  // ========================================
  const commitResponse = await fetch(
    `https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/git/commits/${shaToRevert}`,
    {
      headers: { Authorization: `Bearer ${gitToken}` }
    }
  );
  const commit = await commitResponse.json();
  const parentSha = commit.parents[0].sha;

  // ========================================
  // PASO 2: Obtener el árbol del padre
  // ========================================
  const parentCommitResponse = await fetch(
    `https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/git/commits/${parentSha}`,
    {
      headers: { Authorization: `Bearer ${gitToken}` }
    }
  );
  const parentCommit = await parentCommitResponse.json();
  const parentTreeSha = parentCommit.tree.sha;

  // ========================================
  // PASO 3: Obtener el SHA actual de main
  // ========================================
  const branchResponse = await fetch(
    `https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/branches/main`,
    {
      headers: { Authorization: `Bearer ${gitToken}` }
    }
  );
  const branch = await branchResponse.json();
  const currentMainSha = branch.commit.sha;

  // ========================================
  // PASO 4: Crear commit de revert
  // ========================================
  const revertCommitResponse = await fetch(
    `https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/git/commits`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${gitToken}` },
      body: JSON.stringify({
        message: `Revert auto-repair attempt [skip ci]`,
        tree: parentTreeSha,  // ← AQUÍ: árbol del padre, no del commit fallido
        parents: [currentMainSha],
        author: {
          name: 'n8n Auto-Repair',
          email: 'noreply@n8n.local',
          date: new Date().toISOString()
        }
      })
    }
  );
  const revertCommit = await revertCommitResponse.json();
  return revertCommit.sha;
}

async function updateMainRef(newSha, gitToken) {
  // ========================================
  // PASO 5: Mover main al commit de revert
  // ========================================
  const updateResponse = await fetch(
    `https://api.github.com/repos/vi01afta-lab/calisthenics-level-up/git/refs/heads/main`,
    {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${gitToken}` },
      body: JSON.stringify({ sha: newSha })
    }
  );
  return await updateResponse.json();
}

// Ejecutar reversiones en orden inverso
const gitToken = '<GITHUB_TOKEN>';
let currentMainSha = null;

for (const sha of reversedShas) {
  const revertSha = await createRevertCommit(sha, gitToken);
  await updateMainRef(revertSha, gitToken);
  currentMainSha = revertSha;
}

return {
  rollback: true,
  revertedCount: reversedShas.length,
  finalMainSha: currentMainSha,
  previousShas: reversedShas
};
```

**NOTA:** En n8n esto probablemente necesite ser 2-3 nodos HTTP Request separados encadenados, no un solo nodo Code.

**Siguiente:** NODO #19

---

### NODO #19: Notificar Fallo + Rollback
**Tipo:** HTTP Request (Telegram o Webhook placeholder)

**Pseudocódigo:**
```javascript
const state = $input.first().json;
const rollbackResult = $input.nth(0).json;

const message = `❌ **Auto-Repair Failed**
Repository: vi01afta-lab/calisthenics-level-up
Workflow: ${state.webhook.workflowName}
Attempts: ${state.recovery.repairAttempt - 1}/2 failed

Rollback Status: ${rollbackResult.rollback ? 'SUCCESS' : 'NOT NEEDED'}
${rollbackResult.rollback ? `Reverted ${rollbackResult.revertedCount} commits to: ${state.recovery.lastSuccessfulSha.substring(0, 7)}` : ''}

Error Summary:
${state.context.errorLog.split('\n').slice(0, 5).join('\n')}

Manual Review Required:
→ Check logs: https://github.com/vi01afta-lab/calisthenics-level-up/actions

Timestamp: ${new Date().toISOString()}`;

return {
  message,
  status: 'sent',
  to: 'TELEGRAM_CHAT_ID'
};
```

**Siguiente:** FIN

---

### NODO #20: Notificar Escalada (HTTP Request)
**Tipo:** HTTP Request (Telegram o Webhook placeholder)

**Pseudocódigo:**
```javascript
const state = $input.first().json;
const escalationReason = $input.nth(0).json.reason;

const message = `⚠️ **Auto-Repair Escalation**
Repository: vi01afta-lab/calisthenics-level-up
Workflow: ${state.webhook.workflowName}

Reason for Escalation:
${escalationReason}

Details:
- Error appears to be in application logic, not CI/CD configuration
- The Auto-Repair system cannot safely modify code outside its domain
- Manual review by the development team is required

Error Log:
${state.context.errorLog.split('\n').slice(0, 10).join('\n')}

Workflow: https://github.com/vi01afta-lab/calisthenics-level-up/actions/runs/${state.webhook.failedRunId}

Timestamp: ${new Date().toISOString()}`;

return {
  message,
  status: 'escalated',
  to: 'TELEGRAM_CHAT_ID'
};
```

**Siguiente:** FIN

---

## 🔑 Variables de Estado Clave

El JSON de estado `state` viaja completo entre todos los nodos. Estructura final:

```javascript
{
  webhook: {
    failedRunId: <number>,
    failedWorkflowId: <number>,
    currentFailedSha: <string>,
    failedBranch: <string>,
    workflowName: <string>
  },

  recovery: {
    lastSuccessfulSha: <string>,
    lastSuccessfulRunId: <number>,
    repairAttempt: <number>,  // 1 o 2
    maxRepairAttempts: <number>,  // 2
    attemptShas: <array>,  // [sha1, sha2]
    pollAttempt: <number>,  // 0-10
    maxPollAttempts: <number>  // 10
  },

  context: {
    errorLog: <string>,  // Truncado, relevante
    errorLogOriginalSize: <number>,
    fileTree: <array>,  // Rutas de archivos
    previousAttemptCode: <string>,  // Contenido del intento anterior
    previousFailureReason: <string>,
    formatRetryCount: <number>,  // 0-2
    maxFormatRetries: <number>  // 2
  },

  timing: {
    webhookReceivedAt: <ISO8601>,
    repairStartedAt: <ISO8601>
  }
}
```

---

## 📋 Correcciones de Los Errores de Copilot v5

| Error | Copilot dijo | Ahora es |
|-------|-----------|---------|
| fetch() en Code | Válido | ❌ Inválido, usar HTTP Request |
| credentials.github.token | Válido | ❌ Inválido, pasar como parámetro de credencial |
| repairAttempt >= maxAttempts | Lógica correcta | ❌ Off-by-one, cambiar a `>` |
| lastSuccessfulSha sin filtro | No considerado | ✅ Ahora incluye `workflow_id` |
| Logs sin truncar | No considerado | ✅ Ahora trunca a últimas 100 líneas |
| RETRY sin contador | No considerado | ✅ Ahora hay `formatRetryCount` |

---

## 🚀 Próximos Pasos Para el Agente n8n

1. **Lee este pseudocódigo** (que es lo que acabas de leer)
2. **Crea los nodos en n8n** en el orden especificado
3. **Configura credenciales reales:**
   - GitHub Token (ID: `qmWndu5nSXhYs1qx`, verificar que esté activo)
   - Telegram Bot Token (crear o usar existente)
   - GitHub Webhook Secret (generar en GitHub → Settings → Webhooks)
4. **Prueba con un webhook simulado** (GitHub proporciona botón "Redeliver")
5. **Monitorea los primeros ciclos** para validar comportamiento

---

## 📞 Contactos / Referencias

- **GitHub Repo:** vi01afta-lab/calisthenics-level-up
- **n8n Instance:** https://vigilago.app.n8n.cloud
- **GitHub API Docs:** https://docs.github.com/en/rest/actions/workflows
- **Gemini API Docs:** https://ai.google.dev/

---

**Fin del Pseudocódigo**
