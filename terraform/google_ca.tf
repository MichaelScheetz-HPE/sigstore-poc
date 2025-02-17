# CA pool to use for GCP CA services for Fulcio
resource "google_privateca_ca_pool" "default" {
  name     = "sigstore-poc-${var.WORKSPACE_ID}"
  location = var.DEFAULT_LOCATION
  tier     = "DEVOPS"
  publishing_options {
    publish_ca_cert = true
    publish_crl     = false
  }
  issuance_policy {
    maximum_lifetime = "50000s"
    allowed_issuance_modes {
      allow_csr_based_issuance    = true
      allow_config_based_issuance = true
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

# Certificate Authority for Fulcio to requests certs from
resource "google_privateca_certificate_authority" "default" {
  pool                     = google_privateca_ca_pool.default.name
  certificate_authority_id = "sigstore-${var.PROJECT_ID}-${var.WORKSPACE_ID}"
  location                 = var.DEFAULT_LOCATION
  project                  = var.PROJECT_ID

  key_spec {
    algorithm = "EC_P384_SHA384"
  }

  config {
    subject_config {
      subject {
        organization = "Example, Org."
        common_name  = "Example Authority"
      }
    }
    x509_config {
      ca_options {
        # is_ca *MUST* be true for certificate authorities
        is_ca                  = true
        max_issuer_path_length = 10
      }
      key_usage {
        base_key_usage {
          # cert_sign and crl_sign *MUST* be true for certificate authorities
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth  = true
          code_signing = true
        }
      }
    }

  }
  lifecycle {
    prevent_destroy = true
  }
  depends_on = [
    google_privateca_ca_pool.default
  ]
}

# Allows the createcerts k8s SA to the assume the google SA
resource "google_service_account_iam_member" "createcerts_account_iam" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[fulcio-system/createcerts]"
  service_account_id = google_service_account.gke_workload.name
  depends_on         = [google_service_account.gke_workload]
}

# Allows the Fulcio k8s SA to the assume the google SA
resource "google_service_account_iam_member" "fulcio_account_iam" {
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.PROJECT_ID}.svc.id.goog[fulcio-system/fulcio]"
  service_account_id = google_service_account.gke_workload.name
  depends_on         = [google_service_account.gke_workload]
}

output "gcp_private_ca_parent" {
  value = google_privateca_ca_pool.default.id
}

output "ca_certificate" {
  value = google_privateca_certificate_authority.default.pem_ca_certificates
}