resource "google_service_account" "rag-cf-sa" {
  account_id   = "rag-cf-sa"
  display_name = "Cloud Function Service Account"
  project      = var.PROJECT_ID
}

variable "function_roles" {
  type = list(string)
  default = [
    "roles/aiplatform.user",
    "roles/storage.objectViewer",
    "roles/eventarc.eventReceiver"
  ]
}

resource "google_project_iam_member" "rag-cf-sa-bindings" {
  for_each = toset(var.function_roles)
  project  = var.PROJECT_ID
  role     = each.value
  member   = "serviceAccount:${google_service_account.rag-cf-sa.email}"
}