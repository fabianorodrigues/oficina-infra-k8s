#!/usr/bin/env bash
set -euo pipefail

MODE="plan"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument."
      exit 1
      ;;
  esac
done

if [ "${MODE}" != "plan" ] && [ "${MODE}" != "apply" ]; then
  echo "Invalid adoption mode."
  exit 1
fi

RESOURCE_ADDRESSES=(
  "newrelic_alert_policy.oficina[0]"
  "newrelic_nrql_alert_condition.api_5xx[0]"
  "newrelic_nrql_alert_condition.ordem_servico_failure[0]"
  "newrelic_nrql_alert_condition.kubernetes_cpu[0]"
  "newrelic_nrql_alert_condition.kubernetes_memory[0]"
  "newrelic_notification_destination.email[0]"
  "newrelic_notification_channel.email[0]"
  "newrelic_workflow.oficina[0]"
  "newrelic_synthetics_monitor.health[0]"
  "newrelic_one_dashboard_json.oficina[0]"
  "kubernetes_namespace.newrelic[0]"
  "helm_release.nri_bundle[0]"
)

status() {
  local address="$1"
  local value="$2"
  printf '%s: %s\n' "${address}" "${value}" >&2
}

fail_status() {
  local address="$1"
  local value="$2"
  status "${address}" "${value}"
  exit 1
}

normalize_bool() {
  local value
  value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"

  case "${value}" in
    1|true|yes|y|on)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

enabled_new_relic="$(normalize_bool "${TF_VAR_enable_new_relic:-${ENABLE_NEW_RELIC:-false}}")"

if [ "${enabled_new_relic}" != "true" ]; then
  for address in "${RESOURCE_ADDRESSES[@]}"; do
    status "${address}" "disabled"
  done
  exit 0
fi

for command_name in curl jq terraform; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command is unavailable."
    exit 1
  fi
done

for var_name in PROJECT_NAME ENVIRONMENT NEW_RELIC_USER_API_KEY NEW_RELIC_ACCOUNT_ID; do
  if [ -z "${!var_name:-}" ]; then
    echo "Required observability adoption variable is missing."
    exit 1
  fi
done

if ! printf '%s' "${NEW_RELIC_ACCOUNT_ID}" | grep -Eq '^[0-9]+$'; then
  echo "Required observability adoption variable is invalid."
  exit 1
fi

new_relic_region="$(printf '%s' "${NEW_RELIC_REGION:-US}" | tr '[:lower:]' '[:upper:]')"
case "${new_relic_region}" in
  US)
    nerdgraph_url="https://api.newrelic.com/graphql"
    ;;
  EU)
    nerdgraph_url="https://api.eu.newrelic.com/graphql"
    ;;
  *)
    echo "Required observability adoption variable is invalid."
    exit 1
    ;;
esac

name_prefix="$(printf '%s-%s' "${PROJECT_NAME}" "${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]')"
api_gateway_url="${TF_VAR_api_gateway_url:-${API_GATEWAY_URL:-}}"

state_has() {
  local address="$1"
  terraform state list 2>/dev/null | grep -Fx -- "${address}" >/dev/null 2>&1
}

state_id() {
  local address="$1"
  terraform state show -no-color "${address}" 2>/dev/null \
    | sed -n 's/^[[:space:]]*id[[:space:]]*=[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' \
    | head -n 1
}

import_resource() {
  local address="$1"
  local import_id="$2"

  if [ -z "${import_id}" ] || [ "${import_id}" = "null" ]; then
    fail_status "${address}" "import failed"
  fi

  if [ "${MODE}" = "plan" ]; then
    status "${address}" "would import"
    return 0
  fi

  if terraform import -input=false "${address}" "${import_id}" >/tmp/adopt-observability-import.log 2>&1; then
    rm -f /tmp/adopt-observability-import.log
    status "${address}" "imported"
    return 0
  fi

  rm -f /tmp/adopt-observability-import.log
  fail_status "${address}" "import failed"
}

graphql() {
  local query="$1"
  local variables="$2"
  local payload
  local response

  payload="$(jq -cn --arg query "${query}" --argjson variables "${variables}" '{query: $query, variables: $variables}')"

  if ! response="$(curl -fsS \
      -H "Content-Type: application/json" \
      -H "API-Key: ${NEW_RELIC_USER_API_KEY}" \
      --data "${payload}" \
      "${nerdgraph_url}" 2>/dev/null)"; then
    echo "New Relic discovery failed."
    exit 1
  fi

  if jq -e '(.errors // []) | length > 0' >/dev/null 2>&1 <<<"${response}"; then
    echo "New Relic discovery failed."
    exit 1
  fi

  printf '%s' "${response}"
}

single_match_id() {
  local address="$1"
  local json="$2"
  local jq_filter="$3"
  local expected_name="$4"
  local id_filter="$5"
  local count
  local import_id

  count="$(jq --arg name "${expected_name}" "${jq_filter} | map(select(.name == \$name)) | length" <<<"${json}")"

  if [ "${count}" -eq 0 ]; then
    status "${address}" "not found/create planned"
    printf ''
    return 0
  fi

  if [ "${count}" -gt 1 ]; then
    fail_status "${address}" "ambiguous/fail"
  fi

  import_id="$(jq -r --arg name "${expected_name}" "${jq_filter} | map(select(.name == \$name)) | .[0] | ${id_filter} // empty" <<<"${json}")"
  if [ -z "${import_id}" ] || [ "${import_id}" = "null" ]; then
    fail_status "${address}" "import failed"
  fi

  printf '%s' "${import_id}"
}

discover_policy() {
  local address="newrelic_alert_policy.oficina[0]"
  local expected_name="${name_prefix}-observability"
  local query
  local variables
  local response
  local policy_id
  local current_state_id

  if state_has "${address}"; then
    status "${address}" "managed"
    current_state_id="$(state_id "${address}")"
    if [ -n "${current_state_id}" ]; then
      printf '%s' "${current_state_id%%:*}"
    fi
    return 0
  fi

  query='query($accountId: Int!, $name: String!) {
    actor {
      account(id: $accountId) {
        alerts {
          policiesSearch(searchCriteria: { name: $name }) {
            policies {
              id
              name
            }
          }
        }
      }
    }
  }'
  variables="$(jq -cn --argjson accountId "${NEW_RELIC_ACCOUNT_ID}" --arg name "${expected_name}" '{accountId: $accountId, name: $name}')"
  response="$(graphql "${query}" "${variables}")"
  policy_id="$(single_match_id "${address}" "${response}" '.data.actor.account.alerts.policiesSearch.policies // []' "${expected_name}" '.id')"

  if [ -z "${policy_id}" ]; then
    return 0
  fi

  import_resource "${address}" "${policy_id}:${NEW_RELIC_ACCOUNT_ID}"
  printf '%s' "${policy_id}"
}

discover_nrql_condition() {
  local address="$1"
  local expected_name="$2"
  local policy_id="$3"
  local query
  local variables
  local response
  local import_id

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  if [ -z "${policy_id}" ]; then
    status "${address}" "not found/create planned"
    return 0
  fi

  query='query($accountId: Int!, $policyId: ID!, $name: String!) {
    actor {
      account(id: $accountId) {
        alerts {
          nrqlConditionsSearch(searchCriteria: { policyId: $policyId, name: $name }) {
            nrqlConditions {
              id
              name
              policyId
              type
            }
          }
        }
      }
    }
  }'
  variables="$(jq -cn --argjson accountId "${NEW_RELIC_ACCOUNT_ID}" --arg policyId "${policy_id}" --arg name "${expected_name}" '{accountId: $accountId, policyId: $policyId, name: $name}')"
  response="$(graphql "${query}" "${variables}")"

  import_id="$(single_match_id "${address}" "${response}" '.data.actor.account.alerts.nrqlConditionsSearch.nrqlConditions // [] | map(select((.type | ascii_downcase) == "static"))' "${expected_name}" '.id')"
  if [ -z "${import_id}" ]; then
    return 0
  fi

  import_resource "${address}" "${policy_id}:${import_id}:static"
}

discover_notification_destination() {
  local address="newrelic_notification_destination.email[0]"
  local expected_name="${name_prefix}-observability-email"
  local query
  local variables
  local response
  local destination_id
  local current_state_id

  if state_has "${address}"; then
    status "${address}" "managed"
    current_state_id="$(state_id "${address}")"
    if [ -n "${current_state_id}" ]; then
      printf '%s' "${current_state_id}"
    fi
    return 0
  fi

  query='query($accountId: Int!, $name: String!) {
    actor {
      account(id: $accountId) {
        aiNotifications {
          destinations(filters: { name: $name }) {
            entities {
              id
              name
              type
            }
          }
        }
      }
    }
  }'
  variables="$(jq -cn --argjson accountId "${NEW_RELIC_ACCOUNT_ID}" --arg name "${expected_name}" '{accountId: $accountId, name: $name}')"
  response="$(graphql "${query}" "${variables}")"
  destination_id="$(single_match_id "${address}" "${response}" '.data.actor.account.aiNotifications.destinations.entities // [] | map(select(.type == "EMAIL"))' "${expected_name}" '.id')"

  if [ -z "${destination_id}" ]; then
    return 0
  fi

  import_resource "${address}" "${destination_id}"
  printf '%s' "${destination_id}"
}

discover_notification_channel() {
  local expected_destination_id="$1"
  local address="newrelic_notification_channel.email[0]"
  local expected_name="${name_prefix}-observability-email"
  local query
  local variables
  local response
  local count
  local import_id
  local destination_id

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  query='query($accountId: Int!, $name: String!) {
    actor {
      account(id: $accountId) {
        aiNotifications {
          channels(filters: { name: $name }) {
            entities {
              id
              name
              type
              destinationId
            }
          }
        }
      }
    }
  }'
  variables="$(jq -cn --argjson accountId "${NEW_RELIC_ACCOUNT_ID}" --arg name "${expected_name}" '{accountId: $accountId, name: $name}')"
  response="$(graphql "${query}" "${variables}")"
  count="$(jq --arg name "${expected_name}" '[.data.actor.account.aiNotifications.channels.entities[]? | select(.name == $name and .type == "EMAIL")] | length' <<<"${response}")"

  if [ "${count}" -eq 0 ]; then
    status "${address}" "not found/create planned"
    return 0
  fi

  if [ "${count}" -gt 1 ]; then
    fail_status "${address}" "ambiguous/fail"
  fi

  import_id="$(jq -r --arg name "${expected_name}" '.data.actor.account.aiNotifications.channels.entities[]? | select(.name == $name and .type == "EMAIL") | .id // empty' <<<"${response}")"
  destination_id="$(jq -r --arg name "${expected_name}" '.data.actor.account.aiNotifications.channels.entities[]? | select(.name == $name and .type == "EMAIL") | .destinationId // empty' <<<"${response}")"

  if [ -z "${import_id}" ] || [ -z "${destination_id}" ] || [ -z "${expected_destination_id}" ] || [ "${destination_id}" != "${expected_destination_id}" ]; then
    fail_status "${address}" "import failed"
  fi

  import_resource "${address}" "${import_id}"
}

discover_workflow() {
  local address="newrelic_workflow.oficina[0]"
  local expected_name="${name_prefix}-observability"
  local query
  local variables
  local response
  local import_id

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  query='query($accountId: Int!, $name: String!) {
    actor {
      account(id: $accountId) {
        aiWorkflows {
          workflows(filters: { name: $name }) {
            entities {
              id
              name
            }
          }
        }
      }
    }
  }'
  variables="$(jq -cn --argjson accountId "${NEW_RELIC_ACCOUNT_ID}" --arg name "${expected_name}" '{accountId: $accountId, name: $name}')"
  response="$(graphql "${query}" "${variables}")"
  import_id="$(single_match_id "${address}" "${response}" '.data.actor.account.aiWorkflows.workflows.entities // []' "${expected_name}" '.id')"

  if [ -z "${import_id}" ]; then
    return 0
  fi

  import_resource "${address}" "${import_id}"
}

discover_entity_by_search() {
  local address="$1"
  local expected_name="$2"
  local search_query="$3"
  local query
  local variables
  local response
  local import_id

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  query='query($query: String!) {
    actor {
      entitySearch(query: $query) {
        results {
          entities {
            guid
            name
          }
        }
      }
    }
  }'
  variables="$(jq -cn --arg query "${search_query}" '{query: $query}')"
  response="$(graphql "${query}" "${variables}")"
  import_id="$(single_match_id "${address}" "${response}" '.data.actor.entitySearch.results.entities // []' "${expected_name}" '.guid')"

  if [ -z "${import_id}" ]; then
    return 0
  fi

  import_resource "${address}" "${import_id}"
}

discover_namespace() {
  local address="kubernetes_namespace.newrelic[0]"

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  if kubectl get namespace newrelic >/dev/null 2>&1; then
    import_resource "${address}" "newrelic"
    return 0
  fi

  status "${address}" "not found/create planned"
}

discover_helm_release() {
  local address="helm_release.nri_bundle[0]"

  if state_has "${address}"; then
    status "${address}" "managed"
    return 0
  fi

  if helm status newrelic-bundle --namespace newrelic >/dev/null 2>&1; then
    import_resource "${address}" "newrelic/newrelic-bundle"
    return 0
  fi

  status "${address}" "not found/create planned"
}

policy_id="$(discover_policy)"

discover_nrql_condition "newrelic_nrql_alert_condition.api_5xx[0]" "${name_prefix}-api-5xx" "${policy_id}"
discover_nrql_condition "newrelic_nrql_alert_condition.ordem_servico_failure[0]" "${name_prefix}-ordem-servico-falha" "${policy_id}"
discover_nrql_condition "newrelic_nrql_alert_condition.kubernetes_cpu[0]" "${name_prefix}-kubernetes-cpu-alta" "${policy_id}"
discover_nrql_condition "newrelic_nrql_alert_condition.kubernetes_memory[0]" "${name_prefix}-kubernetes-memoria-alta" "${policy_id}"

destination_id="$(discover_notification_destination)"
discover_notification_channel "${destination_id}"
discover_workflow

if [ -n "${api_gateway_url}" ]; then
  discover_entity_by_search "newrelic_synthetics_monitor.health[0]" "${name_prefix}-health" "domain = 'SYNTH' and type = 'MONITOR' and name = '${name_prefix}-health'"
else
  status "newrelic_synthetics_monitor.health[0]" "disabled"
fi

discover_entity_by_search "newrelic_one_dashboard_json.oficina[0]" "${name_prefix}-observability" "domain = 'VIZ' and type = 'DASHBOARD' and name = '${name_prefix}-observability'"

discover_namespace
discover_helm_release
