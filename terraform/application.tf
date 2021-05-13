
############################################ Gloo Edge ############################################

data "kubectl_file_documents" "bookinfo_no_v3" {
  content = file("${path.module}/misc/bookinfo/bookinfo-nov3.yaml")
}

data "kubectl_file_documents" "bookinfo" {
  content = file("${path.module}/misc/bookinfo/bookinfo.yaml")
}

resource "helm_release" "gloo_edge_first_cluster" {

  provider         = helm.first_cluster
  name             = "glooe"
  version          = "1.7.2"
  repository       = "http://storage.googleapis.com/gloo-ee-helm"
  chart            = "gloo-ee"
  namespace        = "gloo-system"
  create_namespace = true


  set {
    name  = "license_key"
    value = var.license
  }
  /*
    set {
    name = "global.istioSDS.enabled"
    value = true
  }
*/
}


resource "helm_release" "gloo_edge_second_cluster" {

  provider         = helm.second_cluster
  name             = "glooe"
  version          = "1.7.2"
  repository       = "http://storage.googleapis.com/gloo-ee-helm"
  chart            = "gloo-ee"
  namespace        = "gloo-system"
  create_namespace = true


  set {
    name  = "license_key"
    value = var.license
  }

  /*
    set {
    name = "global.istioSDS.enabled"
    value = true
  }
*/
}


############################################ Argocd ############################################


data "http" "argocd" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml"
}

data "kubectl_file_documents" "argocd" {
  content = data.http.argocd.body
}


resource "kubernetes_namespace" "argocd_namespace_management_cluster" {
  provider = kubernetes.management_cluster
  metadata {
    name = "argocd"

  }
}


resource "kubernetes_namespace" "argocd_namespace_first_cluster" {
  provider = kubernetes.first_cluster
  metadata {
    name = "argocd"

  }
}

resource "kubernetes_namespace" "argocd_namespace_second_cluster" {
  provider = kubernetes.second_cluster
  metadata {
    name = "argocd"
  }
}

resource "kubectl_manifest" "argocd_management_cluster" {

  override_namespace = "argocd"
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)

  depends_on = [
    kubernetes_namespace.argocd_namespace_management_cluster,
  ]

  provider = kubectl.management_cluster
}

resource "kubectl_manifest" "argocd_first_cluster" {

  override_namespace = "argocd"
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)

  depends_on = [
    kubernetes_namespace.argocd_namespace_first_cluster,
  ]

  provider = kubectl.first_cluster
}


resource "kubectl_manifest" "argocd_second_cluster" {

  override_namespace = "argocd"
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)

  depends_on = [
    kubernetes_namespace.argocd_namespace_second_cluster,
  ]

  provider = kubectl.second_cluster
}



############################################ Book info ############################################


resource "kubernetes_namespace" "bookinfo_namespace_first_cluster" {
  provider = kubernetes.first_cluster
  metadata {
    name = "bookinfo"


    labels = {
      istio-injection = "enabled"
    }
  }
}

resource "kubernetes_namespace" "bookinfo_namespace_second_cluster" {
  provider = kubernetes.second_cluster
  metadata {
    name = "bookinfo"


    labels = {
      istio-injection = "enabled"

    }
  }
}


resource "kubectl_manifest" "bookinfo_first_cluster" {

  override_namespace = "bookinfo"
  count              = length(data.kubectl_file_documents.bookinfo_no_v3.documents)
  yaml_body          = element(data.kubectl_file_documents.bookinfo_no_v3.documents, count.index)

  depends_on = [
    kubernetes_namespace.bookinfo_namespace_first_cluster,
  ]

  provider = kubectl.first_cluster
}


resource "kubectl_manifest" "bookinfo_second_cluster" {

  override_namespace = "bookinfo"
  count              = length(data.kubectl_file_documents.bookinfo.documents)
  yaml_body          = element(data.kubectl_file_documents.bookinfo.documents, count.index)

  depends_on = [
    kubernetes_namespace.bookinfo_namespace_second_cluster,
  ]

  provider = kubectl.second_cluster
}

 