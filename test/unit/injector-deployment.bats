#!/usr/bin/env bats

load _helpers

@test "injector/deployment: default injector.enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "injector/deployment: enable with injector.enabled true" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "injector/deployment: disable with global.enabled" {
  cd `chart_dir`
  local actual=$( (helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'global.enabled=false' \
      --set 'injector.enabled=true' \
      . || echo "---") | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "injector/deployment: image defaults to injector.image" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.image.repository=foo' \
      --set 'injector.image.tag=1.2.3' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo:1.2.3" ]

  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.image.repository=foo' \
      --set 'injector.image.tag=1.2.3' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo:1.2.3" ]
}

@test "injector/deployment: default imagePullPolicy" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].imagePullPolicy' | tee /dev/stderr)
  [ "${actual}" = "IfNotPresent" ]
}

@test "injector/deployment: default resources" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "injector/deployment: custom resources" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.enabled=true' \
      --set 'injector.resources.requests.memory=256Mi' \
      --set 'injector.resources.requests.cpu=250m' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.requests.memory' | tee /dev/stderr)
  [ "${actual}" = "256Mi" ]

  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.enabled=true' \
      --set 'injector.resources.limits.memory=256Mi' \
      --set 'injector.resources.limits.cpu=250m' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.limits.memory' | tee /dev/stderr)
  [ "${actual}" = "256Mi" ]

  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.enabled=true' \
      --set 'injector.resources.requests.cpu=250m' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.requests.cpu' | tee /dev/stderr)
  [ "${actual}" = "250m" ]

  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.enabled=true' \
      --set 'injector.resources.limits.cpu=250m' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.limits.cpu' | tee /dev/stderr)
  [ "${actual}" = "250m" ]
}

@test "injector/deployment: enable metrics" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.metrics.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[9].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_TELEMETRY_PATH" ]

  local actual=$(echo $object |
      yq -r '.[9].value' | tee /dev/stderr)
  [ "${actual}" = "/metrics" ]
}

@test "injector/deployment: manual TLS environment vars" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.certs.secretName=foobar' \
      --set 'injector.certs.certName=test.crt' \
      --set 'injector.certs.keyName=test.key' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[5].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_TLS_CERT_FILE" ]

  local actual=$(echo $object |
      yq -r '.[5].value' | tee /dev/stderr)
  [ "${actual}" = "/etc/webhook/certs/test.crt" ]

  local actual=$(echo $object |
      yq -r '.[6].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_TLS_KEY_FILE" ]

  local actual=$(echo $object |
      yq -r '.[6].value' | tee /dev/stderr)
  [ "${actual}" = "/etc/webhook/certs/test.key" ]
}

@test "injector/deployment: auto TLS by default" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]

  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[5].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_TLS_AUTO" ]

  local actual=$(echo $object |
      yq -r '.[6].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_TLS_AUTO_HOSTS" ]
}

@test "injector/deployment: with externalVaultAddr" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.externalVaultAddr=http://vault-outside' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[2].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_VAULT_ADDR" ]

  local actual=$(echo $object |
      yq -r '.[2].value' | tee /dev/stderr)
  [ "${actual}" = "http://vault-outside" ]
}

@test "injector/deployment: without externalVaultAddr" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --release-name not-external-test  \
      --namespace default \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[2].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_VAULT_ADDR" ]

  local actual=$(echo $object |
      yq -r '.[2].value' | tee /dev/stderr)
  [ "${actual}" = "http://not-external-test-vault.default.svc:8200" ]
}

@test "injector/deployment: default authPath" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[3].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_VAULT_AUTH_PATH" ]

  local actual=$(echo $object |
      yq -r '.[3].value' | tee /dev/stderr)
  [ "${actual}" = "auth/kubernetes" ]
}

@test "injector/deployment: custom authPath" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.authPath=auth/k8s' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[3].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_VAULT_AUTH_PATH" ]

  local actual=$(echo $object |
      yq -r '.[3].value' | tee /dev/stderr)
  [ "${actual}" = "auth/k8s" ]
}

@test "injector/deployment: default logLevel" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_LOG_LEVEL" ]

  local actual=$(echo $object |
      yq -r '.[1].value' | tee /dev/stderr)
  [ "${actual}" = "info" ]
}

@test "injector/deployment: custom logLevel" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.logLevel=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[1].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_LOG_LEVEL" ]

  local actual=$(echo $object |
      yq -r '.[1].value' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "injector/deployment: default logFormat" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[7].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_LOG_FORMAT" ]

  local actual=$(echo $object |
      yq -r '.[7].value' | tee /dev/stderr)
  [ "${actual}" = "standard" ]
}

@test "injector/deployment: custom logFormat" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.logFormat=json' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[7].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_LOG_FORMAT" ]

  local actual=$(echo $object |
      yq -r '.[7].value' | tee /dev/stderr)
  [ "${actual}" = "json" ]
}

@test "injector/deployment: default revoke on shutdown" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[8].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_REVOKE_ON_SHUTDOWN" ]

  local actual=$(echo $object |
      yq -r '.[8].value' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "injector/deployment: custom revoke on shutdown" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.revokeOnShutdown=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[8].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_REVOKE_ON_SHUTDOWN" ]

  local actual=$(echo $object |
      yq -r '.[8].value' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "injector/deployment: disable security context when openshift enabled" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'global.openshift=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
    yq -r '.[9].name' | tee /dev/stderr)
  [ "${actual}" = "AGENT_INJECT_SET_SECURITY_CONTEXT" ]
}

#--------------------------------------------------------------------
# extraEnvironmentVars

@test "injector/deployment: set extraEnvironmentVars" {
  cd `chart_dir`
  local object=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.extraEnvironmentVars.FOO=bar' \
      --set 'injector.extraEnvironmentVars.FOOBAR=foobar' \
      --set 'injector.extraEnvironmentVars.lower\.case=sanitized' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
     yq -r '.[9].name' | tee /dev/stderr)
  [ "${actual}" = "FOO" ]

  local actual=$(echo $object |
      yq -r '.[9].value' | tee /dev/stderr)
  [ "${actual}" = "bar" ]

  local actual=$(echo $object |
      yq -r '.[10].name' | tee /dev/stderr)
  [ "${actual}" = "FOOBAR" ]

  local actual=$(echo $object |
      yq -r '.[10].value' | tee /dev/stderr)
  [ "${actual}" = "foobar" ]

  local actual=$(echo $object |
      yq -r '.[11].name' | tee /dev/stderr)
  [ "${actual}" = "LOWER_CASE" ]

  local actual=$(echo $object |
      yq -r '.[11].value' | tee /dev/stderr)
  [ "${actual}" = "sanitized" ]
}

#--------------------------------------------------------------------
# extra annotations

@test "injector/deployment: default annotations" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "injector/deployment: specify annotations yaml" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.annotations.foo=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

@test "injector/deployment: specify annotations yaml string" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.annotations=foo: bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# affinity

@test "injector/deployment: affinity set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .affinity? == null' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "injector/deployment: affinity can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.affinity=foobar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.affinity == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# tolerations

@test "injector/deployment: tolerations not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .tolerations? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "injector/deployment: tolerations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.tolerations=foobar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.tolerations == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# nodeSelector

@test "injector/deployment: nodeSelector is not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "injector/deployment: nodeSelector can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.nodeSelector=testing' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "testing" ]
}

#--------------------------------------------------------------------
# priorityClassName

@test "injector/deployment: priorityClassName not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .priorityClassName? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "injector/deployment: priorityClassName can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'injector.priorityClassName=armaggeddon' \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .priorityClassName == "armaggeddon"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
#--------------------------------------------------------------------
# OpenShift

@test "injector/deployment: OpenShift - runAsUser disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'global.openshift=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.securityContext.runAsUser | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "injector/deployment: OpenShift - runAsGroup disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml  \
      --set 'global.openshift=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.securityContext.runAsGroup | length > 0' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}
#--------------------------------------------------------------------
# extra labels

@test "injector/deployment: specify extraLabels" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.extraLabels.foo=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.labels.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# hostNetwork

@test "injector/deployment: injector.hostNetwork not set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.hostNetwork' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "injector/deployment: injector.hostNetwork is set" {
  cd `chart_dir`
  local actual=$(helm template \
      --show-only templates/injector-deployment.yaml \
      --set 'injector.hostNetwork=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.hostNetwork' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}
