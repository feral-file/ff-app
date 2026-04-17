def to_release_entries($track):
  [
    (($track.releases // [])[]? | {
      version: (.name // ""),
      status: (.status // ""),
      track: ($track.track // ""),
      codes: [(.versionCodes // [])[]? | tonumber?] | map(select(. != null))
    })
    | .max_code = (if (.codes | length) == 0 then null else (.codes | max) end)
  ];

def to_code_entries($releases):
  [
    $releases[] as $r
    | $r.codes[]? as $c
    | {
        code: $c,
        track: $r.track,
        version: $r.version,
        status: $r.status
      }
  ];

(
  (.tracks // []) | map(select(.track == "internal")) | .[0]
) as $internal_track
| if $internal_track == null then
    "latest_version=0\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
  else
    (to_release_entries($internal_track)) as $releases
    | if ($targetVersion | length) > 0 then
        (to_code_entries($releases | map(select(.version == $targetVersion)))) as $entries
        | if ($entries | length) > 0 then
            ($entries | max_by(.code)) as $latest
            | "latest_version=\($targetVersion)\nlatest_build_number=\($latest.code)\nlatest_version_code=\($latest.code)\nlatest_track=\($latest.track)\nlatest_release_status=\($latest.status)"
          else
            ($releases | map(select(.max_code != null))) as $with_codes
            | if ($with_codes | length) == 0 then
                "latest_version=\($targetVersion)\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
              else
                ($with_codes | max_by(.max_code)) as $latest_release
                | "latest_version=\($targetVersion)\nlatest_build_number=\($latest_release.max_code)\nlatest_version_code=\($latest_release.max_code)\nlatest_track=\($latest_release.track)\nlatest_release_status=\($latest_release.status)"
              end
          end
      else
        ($releases | map(select(.max_code != null))) as $with_codes
        | if ($with_codes | length) == 0 then
            "latest_version=0\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
          else
            ($with_codes | max_by(.max_code)) as $latest_release
            | "latest_version=\(if ($latest_release.version | length) > 0 then $latest_release.version else "0" end)\nlatest_build_number=\($latest_release.max_code)\nlatest_version_code=\($latest_release.max_code)\nlatest_track=\($latest_release.track)\nlatest_release_status=\($latest_release.status)"
          end
      end
  end
