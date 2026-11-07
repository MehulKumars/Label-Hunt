# Label Hunt on Google Play: Mehul's checklist

The build to upload is `build/labelhunt-<version>.aab` (Play preset; check it first with
`bash tools/audit_aab.sh build/labelhunt-0.6.1.aab`). Package `com.tiffingames.labelhunt`: it can never change after
the first upload, but players never see it. The name they see (store title, icon label) can change at any time, so
the trademark check has to be done before the public launch, not before the first upload.

## 0. Before the first upload
- [x] IP India public search: no "Label Hunt" (Mehul, 2026-11-07).
- [ ] Before the public launch: the same search in a browser (each site needs a captcha, so it can't be scripted) on
      USPTO (tmsearch.uspto.gov), WIPO Global Brand Database (branddb.wipo.int) and EUIPO TMview (tmdn.org/tmview).
      Search "Label Hunt" and "LabelHunt"; look at classes 9, 28 and 41.
- [ ] Quick search of "Label Hunt" on the Play Store and the App Store from your phone.
- [x] Save the upload key in 1Password (Mehul, 2026-11-07): one item holding the file
      `%APPDATA%\Godot\keystores\labelhunt-upload.jks` (attach it as a document), its password (the text in
      `labelhunt-upload.password.txt` next to it), the alias `upload` and the SHA-256 fingerprint
      `0B:84:CE:56:5E:2E:32:1E:27:2F:05:BC:6E:F5:F9:94:54:0C:3D:4D:3C:D6:F6:C1:76:D5:5A:65:C9:27:2E:B5`.
      Builds on this PC read the two files; keep them there too.
- [ ] One more copy of the key and its password offline (a USB stick).
- [x] Upload `docs/store/privacy.html` to tiffingames.com as its own page: live at
      https://tiffingames.com/labelhunt/privacy (checked 2026-11-07). The site's existing
      `/privacy` page covers only the website, so it doesn't meet Play's rule that the policy covers the app.

## 1. Create the app (done 2026-11-07)
Play Console > Create app: name **Label Hunt**, default language English, **Game**, **Free**. Accept the
declarations. (Free can't later become paid; in-app purchases stay possible.)

New personal accounts: if the Dashboard asks you to verify access to a real Android device, install the Play
Console app on your phone and sign in with the developer account. It has to be done once before publishing.

## 2. App content (Policy and programs > App content)
| Form | Answer for this build |
|---|---|
| Privacy policy | the tiffingames.com link from step 0 |
| App access | All functionality is available without special access |
| Ads | No, the app does not contain ads |
| Advertising ID | No, the app does not use advertising ID (the build has no AD_ID permission) |
| Content rating | IARC questionnaire: Game, no violence, no fear, no gambling, no user-to-user content, no purchases. Expect Everyone / PEGI 3 |
| Target audience | 13-15, 16-17 and 18+ only (not under 13: that keeps the app outside the Families policy, which matters once ads come) |
| News app | No |
| Data safety | No data collected, no data shared. Encrypted in transit: not applicable (no network). Users can't request deletion because nothing is held; uninstalling removes the save |
| Government / financial / health apps | No |

## 3. Store listing (Grow users > Store presence > Main store listing)
Paste from `docs/store/listing.md`; upload the icon, the feature graphic and the screenshots listed there. Category
Game > Word. Contact email tiffingames.studio@gmail.com, website https://tiffingames.com. Until this is done, the
Play page testers see shows the package name and a plain Android icon instead of "Label Hunt" and its icon.

## 4. Internal testing (Test and release > Testing > Internal testing)
- [x] Create a release with **Play App Signing** on (Google holds the app signing key; the `labelhunt-upload.jks` key
      only uploads, and a lost upload key can be reset through Play support).
- [x] Upload the .aab. 0.6.0 (code 10) went up on 2026-11-07; its icons were blank on phones, fixed in 0.6.1 (code 11).
      Release name: the version. Notes: one line on what to try.
- [x] Testers: the "Dev List" email list (up to 100). Testers open the opt-in link and install from the Play Store,
      not from a file. To update, publish a new release; phones get it through the Play Store, no uninstall.
- Internal tests appear within minutes and skip review.

## 5. Closed testing (needed before production on a new personal account)
- [ ] Create a closed track (for example "Alpha"), add **at least 12 testers** (a Google Group is easiest), roll the
      same build out to it, and send them the opt-in link.
- [ ] Keep at least 12 testers opted in for **14 days in a row**. Ask them to open the game a few times; Google asks
      later how testing went.
- [ ] Then Dashboard > Apply for production, answer the questions about the test, and wait for review (usually
      under 7 days).

## 6. tiffingames.com
| Stage | On the site |
|---|---|
| Internal testing (now) | Only the Label Hunt privacy page. No Play link: it shows "item not found" to anyone not on the tester list |
| Closed testing | A Label Hunt page: one line, 3 or 4 screenshots, the privacy link, and **Join the beta** (a Google Group anyone can join; the closed track lets that group in). Do the USPTO, WIPO and EUIPO searches before it goes up |
| Open testing or launch | Add the official "Get it on Google Play" badge linking to the store page |

## 7. Later
- Every new build needs a higher version code (the Play preset in `export_presets.cfg`; 0.6.0 was 10, 0.6.1 is 11).
- When real ads or purchases arrive (v0.7+): turn on the INTERNET permission (and BILLING for purchases), update the
  privacy policy and the Data safety, Ads and content-rating answers, and add `app-ads.txt` to tiffingames.com for
  AdMob. Play Billing products can be created and test-bought on internal testing; real AdMob ads need the public
  listing and AdMob's app review.
