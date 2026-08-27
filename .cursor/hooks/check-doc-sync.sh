#!/bin/bash
set -euo pipefail

cat >/dev/null

if [ ! -f "docs/00-brief.md" ]; then
  exit 0
fi

changed=$(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)

if [ -z "${changed}" ]; then
  exit 0
fi

code_changed=$(printf '%s\n' "${changed}" | grep -v '^docs/' | grep -v '^\.cursor/' || true)
docs_changed=$(printf '%s\n' "${changed}" | grep '^docs/' || true)

if [ -n "${code_changed}" ] && [ -z "${docs_changed}" ]; then
  printf '%s\n' '{"followup_message":"Código foi alterado sem nenhuma atualização em /docs. Antes de finalizar, acione o MODO SYNC da skill documentation-harness: rode git diff, verifique se as mudanças alteram contratos (04-contracts.md), modelos de dados (02-data-models.md) ou comportamento de features (03-features/*.md), atualize os docs correspondentes e registre em docs/CHANGELOG.md. Se nada em /docs for afetado, apenas confirme isso explicitamente."}'
  exit 0
fi

if [ -n "${docs_changed}" ] && [ -z "${code_changed}" ]; then
  printf '%s\n' '{"followup_message":"/docs foi editado sem mudança de código correspondente. Acione o MODO SYNC (sentido inverso) da skill documentation-harness: verifique se a edição na doc exige mudança no código; se sim, gere um plano do que precisa mudar e peça confirmação ao usuário antes de aplicar. Se a edição for apenas textual (sem impacto em comportamento), confirme isso explicitamente."}'
  exit 0
fi

exit 0
