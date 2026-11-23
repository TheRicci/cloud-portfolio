#!/usr/bin/env bash
# Drill C — File loss and recovery from S3 versions. Sourced by tests/aws/run.sh.

run_drill_c() {
  local start
  start="$(timer_start)"
  local manifest="$RESULTS_DIR/file-manifest.json"

  local overwrite_files=() delete_files=()
  for i in $(seq 0 4); do
    overwrite_files+=("$(jq -r ".[$i].name" "$manifest")")
  done
  for i in $(seq 5 9); do
    delete_files+=("$(jq -r ".[$i].name" "$manifest")")
  done

  note "overwriting S3 files: ${overwrite_files[*]}"
  note "deleting S3 files: ${delete_files[*]}"

  for name in "${overwrite_files[@]}"; do
    echo "CORRUPTED CONTENT" | aws s3 cp - "s3://$BUCKET_NAME/files/$name" --region "$AWS_REGION"
  done
  for name in "${delete_files[@]}"; do
    aws s3 rm "s3://$BUCKET_NAME/files/$name" --region "$AWS_REGION"
  done
  note "S3 test files corrupted and deleted"

  note "recovering S3 files from versions..."
  for name in "${overwrite_files[@]}"; do
    local version_id
    version_id="$(aws s3api list-object-versions \
      --region "$AWS_REGION" \
      --bucket "$BUCKET_NAME" \
      --prefix "files/$name" \
      --query 'Versions[1].VersionId' --output text)"
    if [[ -n "$version_id" && "$version_id" != "None" ]]; then
      aws s3api copy-object \
        --region "$AWS_REGION" \
        --bucket "$BUCKET_NAME" \
        --key "files/$name" \
        --copy-source "$BUCKET_NAME/files/$name?versionId=$version_id" \
        --output text >/dev/null
    fi
  done

  for name in "${delete_files[@]}"; do
    local marker_id
    marker_id="$(aws s3api list-object-versions \
      --region "$AWS_REGION" \
      --bucket "$BUCKET_NAME" \
      --prefix "files/$name" \
      --query 'DeleteMarkers[0].VersionId' --output text)"
    if [[ -n "$marker_id" && "$marker_id" != "None" ]]; then
      aws s3api delete-object \
        --region "$AWS_REGION" \
        --bucket "$BUCKET_NAME" \
        --key "files/$name" \
        --version-id "$marker_id" \
        --output text >/dev/null
    fi
  done

  note "S3 recovery operations complete"

  if verify_files; then
    local elapsed
    elapsed="$(timer_elapsed "$start")"
    pass "drill-c" "all S3 files recovered and verified in ${elapsed}s"
  else
    local elapsed
    elapsed="$(timer_elapsed "$start")"
    fail "drill-c" "S3 file recovery verification failed after ${elapsed}s"
  fi
}
