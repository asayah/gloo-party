
############################################ Gloo Mesh ############################################

resource "helm_release" "gloo_mesh" {
  provider         = helm.management_cluster
  name             = "gloo-mesh"
  version          = "1.0.4"
  repository       = "https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise"
  chart            = "gloo-mesh-enterprise"
  namespace        = "gloo-mesh"
  create_namespace = true

  set {
    name  = "licenseKey"
    value = var.license
  }
}


############################################ Istio ############################################


resource "helm_release" "istio_operator_first_cluster" {
  provider         = helm.first_cluster
  name             = "istio-operator"
  repository       = "./misc"
  chart            = "istio-operator"
  namespace        = "istio-operator"
  create_namespace = true
}



resource "helm_release" "istio_operator_second_cluster" {
  provider         = helm.second_cluster
  name             = "istio-operator"
  repository       = "./misc"
  chart            = "istio-operator"
  namespace        = "istio-operator"
  create_namespace = true
}



resource "kubernetes_namespace" "istio_system_namespace_first_cluster" {
  provider = kubernetes.first_cluster
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_namespace" "istio_system_namespace_second_cluster" {
  provider = kubernetes.second_cluster
  metadata {
    name = "istio-system"
  }
}

resource "kubectl_manifest" "istio_first_cluster" {

  depends_on = [
    kubernetes_namespace.istio_system_namespace_first_cluster,
  ]

  provider  = kubectl.first_cluster
  yaml_body = <<YAML
    
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    metadata:
      name: istiocontrolplane-default
      namespace: istio-system
    spec:
      profile: default
      meshConfig:
        accessLogFile: /dev/stdout
        enableAutoMtls: true
        defaultConfig:
          envoyMetricsService:
            address: enterprise-agent.gloo-mesh:9977
          envoyAccessLogService:
            address: enterprise-agent.gloo-mesh:9977
          proxyMetadata:
            ISTIO_META_DNS_CAPTURE: "true"
            ISTIO_META_DNS_AUTO_ALLOCATE: "true"
            GLOO_MESH_CLUSTER_NAME: cluster1
      values:
        global:
          meshID: mesh1
          multiCluster:
            clusterName: cluster1
          trustDomain: cluster1
          network: network1
          meshNetworks:
            network1:
              endpoints:
              - fromRegistry: cluster1
              gateways:
              - registryServiceName: istio-ingressgateway.istio-system.svc.cluster.local
                port: 443
            vm-network:
      components:
        ingressGateways:
        - name: istio-ingressgateway
          label:
            topology.istio.io/network: network1
          enabled: true
          k8s:
            env:
              # sni-dnat adds the clusters required for AUTO_PASSTHROUGH mode
              - name: ISTIO_META_ROUTER_MODE
                value: "sni-dnat"
              # traffic through this gateway should be routed inside the network
              - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                value: network1
            service:
              ports:
                - name: http2
                  port: 80
                  targetPort: 8080
                - name: https
                  port: 443
                  targetPort: 8443
                - name: tcp-status-port
                  port: 15021
                  targetPort: 15021
                - name: tls
                  port: 15443
                  targetPort: 15443
                - name: tcp-istiod
                  port: 15012
                  targetPort: 15012
                - name: tcp-webhook
                  port: 15017
                  targetPort: 15017
        pilot:
          k8s:
            env:
              - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
                value: "true"
    YAML
}

resource "kubectl_manifest" "istio_second_cluster" {

  depends_on = [
    kubernetes_namespace.istio_system_namespace_second_cluster,
  ]

  provider  = kubectl.second_cluster
  yaml_body = <<YAML
    
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    metadata:
      name: istiocontrolplane-default
      namespace: istio-system
    spec:
      profile: default
      meshConfig:
        accessLogFile: /dev/stdout
        enableAutoMtls: true
        defaultConfig:
          envoyMetricsService:
            address: enterprise-agent.gloo-mesh:9977
          envoyAccessLogService:
            address: enterprise-agent.gloo-mesh:9977
          proxyMetadata:
            ISTIO_META_DNS_CAPTURE: "true"
            ISTIO_META_DNS_AUTO_ALLOCATE: "true"
            GLOO_MESH_CLUSTER_NAME: cluster2
      values:
        global:
          meshID: mesh1
          multiCluster:
            clusterName: cluster2
          trustDomain: cluster2
          network: network2
          meshNetworks:
            network2:
              endpoints:
              - fromRegistry: cluster2
              gateways:
              - registryServiceName: istio-ingressgateway.istio-system.svc.cluster.local
                port: 443
            vm-network:
      components:
        ingressGateways:
        - name: istio-ingressgateway
          label:
            topology.istio.io/network: network2
          enabled: true
          k8s:
            env:
              # sni-dnat adds the clusters required for AUTO_PASSTHROUGH mode
              - name: ISTIO_META_ROUTER_MODE
                value: "sni-dnat"
              # traffic through this gateway should be routed inside the network
              - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                value: network2
            service:
              ports:
                - name: http2
                  port: 80
                  targetPort: 8080
                - name: https
                  port: 443
                  targetPort: 8443
                - name: tcp-status-port
                  port: 15021
                  targetPort: 15021
                - name: tls
                  port: 15443
                  targetPort: 15443
                - name: tcp-istiod
                  port: 15012
                  targetPort: 15012
                - name: tcp-webhook
                  port: 15017
                  targetPort: 15017
        pilot:
          k8s:
            env:
              - name: PILOT_SKIP_VALIDATE_TRUST_DOMAIN
                value: "true"


    YAML
}

############################################ Gloo Mesh - Cluster registration ############################################


data "kubernetes_service" "enterprise_networking" {
  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "enterprise-networking"
    namespace = "gloo-mesh"
  }
  provider = kubernetes.management_cluster
}

output "enterprise_networking" {
  value = data.kubernetes_service.enterprise_networking
}



data "kubernetes_secret" "relay_root_tls_secret" {
  provider = kubernetes.management_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-root-tls-secret"
    namespace = "gloo-mesh"
  }
}
output "relay_root_tls_secret" {
  value = data.kubernetes_secret.relay_root_tls_secret.data["ca.crt"]
}



resource "kubernetes_secret" "relay_root_tls_secret_first_cluster" {
  provider = kubernetes.first_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-root-tls-secret"
    namespace = "gloo-mesh"
  }

  data = {
    "ca.crt" = data.kubernetes_secret.relay_root_tls_secret.data["ca.crt"]
  }
}



resource "kubernetes_secret" "relay_root_tls_secret_second_cluster" {
  provider = kubernetes.second_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-root-tls-secret"
    namespace = "gloo-mesh"
  }

  data = {
    "ca.crt" = data.kubernetes_secret.relay_root_tls_secret.data["ca.crt"]
  }
}



data "kubernetes_secret" "relay_identity_token_secret" {
  provider = kubernetes.management_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-identity-token-secret"
    namespace = "gloo-mesh"
  }
}

output "relay_identity_token_secret" {
  value = data.kubernetes_secret.relay_identity_token_secret.data.token
}




resource "kubernetes_secret" "relay_identity_token_secret_first_cluster" {
  provider = kubernetes.first_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-identity-token-secret"
    namespace = "gloo-mesh"
  }

  data = {
    "token" = data.kubernetes_secret.relay_identity_token_secret.data.token
  }
}


resource "kubernetes_secret" "relay_identity_token_secret_second_cluster" {
  provider = kubernetes.second_cluster

  depends_on = [
    helm_release.gloo_mesh,
  ]
  metadata {
    name      = "relay-identity-token-secret"
    namespace = "gloo-mesh"
  }

  data = {
    "token" = data.kubernetes_secret.relay_identity_token_secret.data.token
  }
}



resource "helm_release" "gloo_mesh_agent_first_cluster" {
  depends_on = [
    kubectl_manifest.istio_first_cluster,
  ]

  provider         = helm.first_cluster
  name             = "enterprise-agent"
  version          = "1.0.4"
  repository       = "https://storage.googleapis.com/gloo-mesh-enterprise/enterprise-agent"
  chart            = "enterprise-agent"
  namespace        = "gloo-mesh"
  create_namespace = true

  set {
    name  = "relay.serverAddress"
    value = "${data.kubernetes_service.enterprise_networking.load_balancer_ingress[0].hostname}:9900"

  }

  set {
    name  = "relay.authority"
    value = "enterprise-networking.gloo-mesh"
  }


  set {
    name  = "relay.clientCertSecret.name"
    value = "relay-client-tls-secret"
  }

  set {
    name  = "relay.clientCertSecret.namespace"
    value = "gloo-mesh"
  }

  set {
    name  = "relay.cluster"
    value = "cluster1"
  }

  set {
    name  = "relay.insecure"
    value = "false"
  }

  set {
    name  = "relay.rootTlsSecret.name"
    value = "relay-root-tls-secret"
  }

  set {
    name  = "relay.rootTlsSecret.namespace"
    value = "gloo-mesh"
  }

  set {
    name  = "relay.tokenSecret.key"
    value = "token"
  }

  set {
    name  = "relay.tokenSecret.name"
    value = "relay-identity-token-secret"
  }

  set {
    name  = "relay.tokenSecret.namespace"
    value = "gloo-mesh"
  }


}



resource "helm_release" "gloo_mesh_agent_second_cluster" {

  depends_on = [
    kubectl_manifest.istio_second_cluster,
  ]
  provider         = helm.second_cluster
  name             = "enterprise-agent"
  version          = "1.0.4"
  repository       = "https://storage.googleapis.com/gloo-mesh-enterprise/enterprise-agent"
  chart            = "enterprise-agent"
  namespace        = "gloo-mesh"
  create_namespace = true

  set {
    name  = "relay.serverAddress"
    value = "${data.kubernetes_service.enterprise_networking.load_balancer_ingress[0].hostname}:9900"
  }

  set {
    name  = "relay.authority"
    value = "enterprise-networking.gloo-mesh"
  }

  set {
    name  = "relay.clientCertSecret.name"
    value = "relay-client-tls-secret"
  }

  set {
    name  = "relay.clientCertSecret.namespace"
    value = "gloo-mesh"
  }

  set {
    name  = "relay.cluster"
    value = "cluster2"
  }

  set {
    name  = "relay.insecure"
    value = "false"
  }

  set {
    name  = "relay.rootTlsSecret.name"
    value = "relay-root-tls-secret"
  }

  set {
    name  = "relay.rootTlsSecret.namespace"
    value = "gloo-mesh"
  }

  set {
    name  = "relay.tokenSecret.key"
    value = "token"
  }

  set {
    name  = "relay.tokenSecret.name"
    value = "relay-identity-token-secret"
  }

  set {
    name  = "relay.tokenSecret.namespace"
    value = "gloo-mesh"
  }

}


resource "kubectl_manifest" "first_cluster_crd" {

  override_namespace = "gloo-mesh"
  yaml_body          = <<YAML
  apiVersion: "multicluster.solo.io/v1alpha1"
  kind: "KubernetesCluster"
  metadata:
    name: "cluster1"
    namespace: "gloo-mesh"
  spec:
    clusterDomain: "cluster.local"
  YAML  

  depends_on = [
    module.management_cluster
  ]

  provider = kubectl.management_cluster
}



resource "kubectl_manifest" "second_cluster_crd" {

  override_namespace = "gloo-mesh"
  yaml_body          = <<YAML
  apiVersion: "multicluster.solo.io/v1alpha1"
  kind: "KubernetesCluster"
  metadata:
    name: "cluster2"
    namespace: "gloo-mesh"
  spec:
    clusterDomain: "cluster.local"
  YAML  

  depends_on = [
    module.management_cluster
  ]

  provider = kubectl.management_cluster
}
