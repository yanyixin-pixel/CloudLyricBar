# CloudLyricBar Manual Test Checklist

## Menu Bar

- Launch with `swift run CloudLyricBarApp`.
- Confirm a compact music item appears in the right side of the macOS menu bar.
- Click the menu bar item and confirm the popover opens below it.
- Click outside the popover and confirm it closes.

## Lyrics

- Use unit-tested sample lyrics to verify current, previous, and next lines in the popover.
- Verify long lyrics scroll in the pure marquee test.
- Confirm missing lyrics display `暂无同步歌词`.

## NetEase Client Handoff

- Install and launch the official NetEase Cloud Music Mac client.
- Trigger song selection from a search result.
- Confirm the official client receives the song deep link if the installed client supports it.
- If deep link playback fails, use the permission settings entry to request Accessibility permission and verify the app reports whether accessibility control is available.

## Login and Library

- Run a local NetEase API service at `http://localhost:3000`.
- Use QR login flow through the configured NetEase API-compatible service.
- Confirm playlists load after login.
- Confirm search returns songs for a known keyword.

## Permission Behavior

- Confirm the app launches without requesting Accessibility permission.
- Confirm no permission prompt appears until a feature requires it.
