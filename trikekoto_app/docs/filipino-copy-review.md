# Filipino copy — review sheet

Every user-facing string in the app, Filipino beside English, grouped by
where it appears. Generated from `lib/l10n/app_fil.arb` and `app_en.arb`,
which are what the app actually renders — so this cannot drift from the
build the way a hand-kept list would.

---

## Read this part first

**The two marks matter more than anything else on this sheet.**

- **`[shipped]`** — this wording was already in the app. It went through
  the end-to-end field test on real handsets, and a driver and a commuter
  both used it without comment. Worth a glance, not a study.
- **`[new]`** — this wording was written by a **non-native speaker** while
  the app was being localised, and *no one has ever read it*. Some of it
  translates screens that were previously English-only and had no Filipino
  at all. **This is where the review should spend its time.**

If you only have twenty minutes, read every `[new]` line and ignore the
rest. That is the honest priority.

**English is a translation here, not the original.** Filipino is the ARB
template. If an English line reads awkwardly, say so too — but a wrong
English line is a cosmetic problem, and a wrong Filipino line is one a
driver hits at a terminal.

---

## Landing

- [ ] **`[new]`** Tricycle rides sa barangay mo, kahit kailan
      - *en:* On-demand tricycle rides for your barangay
- [ ] **`[new]`** Mag-book ng ride
      - *en:* Book a ride
- [ ] **`[new]`** Mag-sign in bilang driver o admin
      - *en:* Driver / Admin sign in
- [ ] **`[shipped]`** Kailangan ng number para makapag-book.
      - *en:* You need a mobile number to book.

## Sign-in and its errors

- [ ] **`[new]`** Mag-sign in
      - *en:* Sign in
- [ ] **`[shipped]`** Ilagay ang code
      - *en:* Enter the code
- [ ] **`[shipped]`** Ano ang number mo?
      - *en:* What is your number?
- [ ] **`[new]`** Padadalhan ka namin ng code para makumpirma. Hindi ito ipapakita sa driver hangga't hindi ka nagbo-book.
      - *en:* We will send you a code to confirm it. Your number is not shown to a driver until you book.
- [ ] **`[new]`** Mobile number
      - *en:* Mobile number
- [ ] **`[new]`** 09XX XXX XXXX
      - *en:* 09XX XXX XXXX
- [ ] **`[new]`** Maglagay ng 11-digit na number na nagsisimula sa 09
      - *en:* Enter an 11-digit mobile number starting 09
- [ ] **`[new]`** Ipinapadala…
      - *en:* Sending…
- [ ] **`[new]`** Ipadala ang code
      - *en:* Send code
- [ ] **`[new]`** Ipinadala ang code sa {number}.
      - *en:* Code sent to {number}.
- [ ] **`[new]`** Anim na numero, ipinadala sa {number}.
      - *en:* Six digits, sent to {number}.
- [ ] **`[new]`** Ilagay ang anim na numero mula sa message.
      - *en:* Enter the six digits from the message.
- [ ] **`[shipped]`** Kumpirmahin
      - *en:* Confirm
- [ ] **`[new]`** Ibang number
      - *en:* Use a different number
- [ ] **`[new]`** Mukhang hindi ito mobile number.
      - *en:* That does not look like a mobile number.
- [ ] **`[new]`** Mali ang code. Tingnan ulit ang message.
      - *en:* Wrong code. Check the message again.
- [ ] **`[new]`** Nag-expire na ang code. Humingi ng bago.
      - *en:* That code expired. Ask for a new one.
- [ ] **`[new]`** Masyadong maraming subok. Maghintay ng ilang minuto bago ulitin.
      - *en:* Too many tries. Wait a few minutes before asking again.
- [ ] **`[new]`** Hindi makapagpadala ng code ngayon. Subukan mamaya.
      - *en:* Cannot send codes right now. Try again later.
- [ ] **`[new]`** Walang connection. Tingnan ang signal mo.
      - *en:* No connection. Check your signal.
- [ ] **`[new]`** Naka-off ang phone sign-in sa project na ito.
      - *en:* Phone sign-in is switched off for this project.
- [ ] **`[new]`** Hindi pumasa ang browser check. I-reload ang page at subukan ulit.
      - *en:* The browser check failed. Reload the page and try again.
- [ ] **`[new]`** Hindi pa naka-register ang app na ito para sa phone sign-in.
      - *en:* This app is not registered for phone sign-in yet.
- [ ] **`[new]`** Wala ang site na ito sa allowed list para sa sign-in.
      - *en:* This site is not on the allowed list for sign-in.
- [ ] **`[new]`** {message} [{code}]
      - *en:* {message} [{code}]
- [ ] **`[new]`** Hindi ma-verify ang number na iyon.
      - *en:* Could not verify that number.
- [ ] **`[new]`** Hindi naipadala ang code. ({detail})
      - *en:* Could not send the code. ({detail})

## Onboarding and photo

- [ ] **`[new]`** Konti na lang
      - *en:* Almost done
- [ ] **`[shipped]`** Litrato — puwedeng laktawan
      - *en:* Photo — you can skip this
- [ ] **`[shipped]`** Anong itatawag namin sa iyo?
      - *en:* What should we call you?
- [ ] **`[shipped]`** Ito ang makikita ng driver kapag sinundo ka.
      - *en:* This is what the driver sees when they collect you.
- [ ] **`[shipped]`** Simulan
      - *en:* Start
- [ ] **`[shipped]`** Pangalan
      - *en:* Name
- [ ] **`[new]`** Ilagay ang pangalan mo
      - *en:* Enter your name
- [ ] **`[new]`** Masyadong mahaba
      - *en:* Too long
- [ ] **`[new]`** {number} — nakumpirma na
      - *en:* {number} — confirmed
- [ ] **`[new]`** Mag-sign out
      - *en:* Sign out
- [ ] **`[shipped]`** Kumuha ng litrato
      - *en:* Take a photo
- [ ] **`[shipped]`** Pumili sa gallery
      - *en:* Choose from gallery
- [ ] **`[shipped]`** Alisin ang litrato
      - *en:* Remove photo
- [ ] **`[new]`** Palitan ang profile photo
      - *en:* Change profile photo
- [ ] **`[new]`** Maglagay ng profile photo
      - *en:* Add a profile photo

## Rider profile and deletion

- [ ] **`[new]`** Profile
      - *en:* Profile
- [ ] **`[shipped]`** Na-save ang profile mo.
      - *en:* Your profile is saved.
- [ ] **`[new]`** Na-save ang pangalan, pero hindi ang litrato. {error}
      - *en:* Name saved, but not the photo. {error}
- [ ] **`[shipped]`** Ito ang makikita ng driver
      - *en:* This is what the driver sees
- [ ] **`[shipped]`** Ise-save ang litrato pagpindot mo ng Save
      - *en:* The photo saves when you press Save
- [ ] **`[shipped]`** Pindutin ang litrato para palitan
      - *en:* Tap the photo to change it
- [ ] **`[new]`** ID verification
      - *en:* ID verification
- [ ] **`[new]`** I-save
      - *en:* Save
- [ ] **`[shipped]`** Hindi mabuksan ang profile
      - *en:* Cannot open your profile
- [ ] **`[shipped]`** Tingnan ang signal mo, tapos subukang muli.
      - *en:* Check your signal, then try again.
- [ ] **`[new]`** Subukang muli
      - *en:* Try again
- [ ] **`[shipped]`** Walang profile
      - *en:* No profile
- [ ] **`[shipped]`** Mag-sign in muli para makagawa ng account.
      - *en:* Sign in again to create an account.
- [ ] **`[shipped]`** Burahin ang account
      - *en:* Delete account
- [ ] **`[shipped]`** Burahin ang account mo?
      - *en:* Delete your account?
- [ ] **`[shipped]`** Mabubura nang tuluyan:
      - *en:* Permanently deleted:
- [ ] **`[new]`** • Ang pangalan at litrato mo ⏎ • Ang ID mo, kung nagpadala ka ⏎ • Ang mga naka-save na lugar ⏎ • Ang account mo — kakailanganin mong magparehistro ulit
      - *en:* • Your name and photo ⏎ • Your ID, if you sent one ⏎ • Your saved places ⏎ • Your account — you would need to register again
- [ ] **`[new]`** Ang mga naunang biyahe ay mananatili bilang record ng TODA — pero tatanggalin dito ang pangalan at number mo, kaya hindi na ito maiuugnay sa iyo.
      - *en:* Past rides stay as a TODA record — but your name and number are removed from them, so they can no longer be traced to you.
- [ ] **`[shipped]`** Hindi na ito maibabalik.
      - *en:* This cannot be undone.
- [ ] **`[shipped]`** Hindi
      - *en:* No
- [ ] **`[shipped]`** Para sa seguridad, mag-sign in muli bago burahin ang account.
      - *en:* For security, sign in again before deleting the account.

## Booking, tracking, rating

- [ ] **`[new]`** Mag-book ng ride
      - *en:* Book a ride
- [ ] **`[new]`** Saan tayo?
      - *en:* Where to?
- [ ] **`[new]`** Ino-offer muna namin ang ride mo sa pinakamalapit na driver.
      - *en:* We offer your ride to the nearest available driver first.
- [ ] **`[new]`** Kasalukuyang location
      - *en:* Current location
- [ ] **`[new]`** Itakda ang sundo
      - *en:* Set pickup
- [ ] **`[new]`** Itakda ang babaan
      - *en:* Set drop-off
- [ ] **`[new]`** Itakda sa mapa ang sundo at babaan mo.
      - *en:* Set both your pickup and drop-off on the map.
- [ ] **`[new]`** Sundo
      - *en:* Pickup
- [ ] **`[new]`** Babaan
      - *en:* Drop-off
- [ ] **`[new]`** Hinahanap ang location mo…
      - *en:* Finding your location…
- [ ] **`[new]`** Itakda sa mapa
      - *en:* Set on map
- [ ] **`[new]`** Pangalan mo
      - *en:* Your name
- [ ] **`[new]`** Ilagay ang pangalan mo
      - *en:* Enter your name
- [ ] **`[new]`** Para matawagan ka ng driver mo.
      - *en:* So your driver can reach you.
- [ ] **`[new]`** Maglagay ng number na matatawagan ng driver
      - *en:* Enter a mobile number the driver can call
- [ ] **`[new]`** Naghahanap ng driver…
      - *en:* Finding a driver…
- [ ] **`[new]`** Maghanap ng driver
      - *en:* Find a driver
- [ ] **`[new]`** Profile
      - *en:* Profile
- [ ] **`[new]`** Mag-report ng problema
      - *en:* Report a problem
- [ ] **`[new]`** Lumabas
      - *en:* Exit
- [ ] **`[new]`** Live tracking
      - *en:* Live tracking
- [ ] **`[new]`** Papunta na sa babaan mo
      - *en:* On the way to your drop-off
- [ ] **`[new]`** {km} km ang layo
      - *en:* {km} km away
- [ ] **`[new]`** Kinakalkula ang ruta…
      - *en:* Working out the route…
- [ ] **`[new]`** Biyahe
      - *en:* Trip
- [ ] **`[new]`** {km} km{minutes}
      - *en:* {km} km{minutes}
- [ ] **`[new]`**  · mga {minutes} min
      - *en:*  · about {minutes} min
- [ ] **`[new]`** Tinatantiya — hindi maabot ang route service
      - *en:* Approximate — could not reach the route service
- [ ] **`[new]`** Subukang muli
      - *en:* Try again
- [ ] **`[new]`** Naghahanap ng driver…
      - *en:* Looking for a driver…
- [ ] **`[new]`** Papunta na ang driver
      - *en:* Driver is on the way
- [ ] **`[new]`** Papunta na sa babaan mo
      - *en:* On the way to your drop-off
- [ ] **`[new]`** Natanong na ang {depth} sa {total} malapit na driver
      - *en:* Asked {depth} of {total} nearby drivers
- [ ] **`[new]`** Tawagan si {name}
      - *en:* Call {name}
- [ ] **`[new]`** Kanselahin ang ride
      - *en:* Cancel ride
- [ ] **`[new]`** Hindi mabuksan ang dialler. Number: {phone}
      - *en:* Could not open the dialler. Number: {phone}
- [ ] **`[new]`** Kumusta ang biyahe mo?
      - *en:* How was your ride?
- [ ] **`[new]`** Bayaran ang nakasaad na TODA fare nang cash.
      - *en:* Pay the posted TODA fare in cash.
- [ ] **`[shipped]`** Salamat sa rating!
      - *en:* Thanks for the rating!

## Location picker

- [ ] **`[new]`** Maghanap ng lugar
      - *en:* Search a place
- [ ] **`[new]`** Hanapin
      - *en:* Search
- [ ] **`[new]`** Walang nakitang "{query}" malapit dito. Kung malayo ito, i-drag muna ang mapa papunta roon — o ilagay ang pin nang manu-mano.
      - *en:* Nothing called "{query}" found near here. If it is far away, drag the map there first — or place the pin by hand.
- [ ] **`[new]`** Naka-off ang location permission. I-on ito sa Settings para ma-center ang mapa sa iyo.
      - *en:* Location permission is off. Enable it in Settings to centre the map on you.
- [ ] **`[new]`** Bigyan ng pangalan ang lugar para makilala ito ng driver mo.
      - *en:* Give this place a name so your driver recognises it.
- [ ] **`[shipped]`** Hinahanap…
      - *en:* Locating…
- [ ] **`[new]`** Nasa akin ngayon
      - *en:* Where I am now
- [ ] **`[new]`** I-drag ang mapa para ilagay ang pin — o hanapin sa itaas, o gamitin ang location mo.
      - *en:* Drag the map to place the pin — or search above, or use your location.
- [ ] **`[new]`** Pangalanan ang lugar
      - *en:* Name this place
- [ ] **`[new]`** hal. Plaza, Palengke, Barangay Hall
      - *en:* e.g. Plaza, Palengke, Barangay Hall
- [ ] **`[new]`** Kumpirmahin ang location
      - *en:* Confirm location

## ID verification

- [ ] **`[new]`** ID verification
      - *en:* ID verification
- [ ] **`[shipped]`** Kunan ng litrato ang ID
      - *en:* Photograph the ID
- [ ] **`[shipped]`** Pumili sa gallery
      - *en:* Choose from gallery
- [ ] **`[shipped]`** Kailangan ng litrato ng ID.
      - *en:* A photo of the ID is required.
- [ ] **`[shipped]`** Kailangan mong pumayag muna.
      - *en:* You need to agree first.
- [ ] **`[shipped]`** Naipadala na. Hihintayin ang review.
      - *en:* Sent. It will be reviewed.
- [ ] **`[shipped]`** Bawiin ang ID?
      - *en:* Withdraw the ID?
- [ ] **`[new]`** Buburahin ang litrato at ang detalye ng ID mo. Puwede kang magpadala ulit anumang oras.
      - *en:* Your ID photo and details will be deleted. You can send it again at any time.
- [ ] **`[shipped]`** Hindi
      - *en:* No
- [ ] **`[shipped]`** Burahin
      - *en:* Delete
- [ ] **`[shipped]`** Nabura na ang ID mo.
      - *en:* Your ID has been deleted.
- [ ] **`[shipped]`** Beripikado na
      - *en:* Verified
- [ ] **`[shipped]`** Nakumpirma ng chapter ang ID mo.
      - *en:* The chapter has confirmed your ID.
- [ ] **`[shipped]`** Hindi tinanggap
      - *en:* Not accepted
- [ ] **`[shipped]`** Walang ibinigay na dahilan.
      - *en:* No reason was given.
- [ ] **`[shipped]`** Hinihintay ang review
      - *en:* Waiting for review
- [ ] **`[shipped]`** Ipinadala na ang ID mo. Aabisuhan ka dito pagkatapos.
      - *en:* Your ID has been sent. You will be told here once it is reviewed.
- [ ] **`[shipped]`** Uri ng ID
      - *en:* ID type
- [ ] **`[new]`** Numero
      - *en:* Number
- [ ] **`[shipped]`** Bawiin at burahin ang ID
      - *en:* Withdraw and delete the ID
- [ ] **`[shipped]`** Buburahin nito ang litrato at ang detalye, kahit na-aprubahan na.
      - *en:* This deletes the photo and the details, even if it was already approved.
- [ ] **`[shipped]`** Kumpirmahin ang pagkakakilanlan
      - *en:* Confirm your identity
- [ ] **`[shipped]`** Kailangan ito ng TODA chapter bago ka makatanggap ng biyahe.
      - *en:* The TODA chapter needs this before you can take rides.
- [ ] **`[shipped]`** Nakakatulong ito para ligtas ang lahat sa biyahe.
      - *en:* This helps keep everyone safe on a ride.
- [ ] **`[shipped]`** Uri ng ID
      - *en:* ID type
- [ ] **`[shipped]`** Numero ng ID
      - *en:* ID number
- [ ] **`[new]`** Masyadong maikli
      - *en:* Too short
- [ ] **`[new]`** Masyadong mahaba
      - *en:* Too long
- [ ] **`[shipped]`** Ipadala para sa review
      - *en:* Send for review
- [ ] **`[shipped]`** Litrato ng ID
      - *en:* Photo of the ID
- [ ] **`[shipped]`** Siguraduhing mabasa ang pangalan at numero
      - *en:* Make sure the name and number can be read
- [ ] **`[shipped]`** Paano gagamitin ang ID mo
      - *en:* How your ID is used
- [ ] **`[new]`** • Titingnan lang ito ng opisyal ng TODA chapter para kumpirmahin kung sino ka. ⏎ • Hindi ito makikita ng ibang pasahero o ng driver mo. ⏎ • Buburahin ito 90 araw matapos ang review, o kaagad kapag binawi mo. ⏎ • Puwede mong burahin anumang oras dito sa screen na ito.
      - *en:* • Only a TODA chapter officer looks at it, to confirm who you are. ⏎ • No other passenger and no driver of yours can see it. ⏎ • It is deleted 90 days after review, or immediately if you withdraw it. ⏎ • You can delete it at any time from this screen.
- [ ] **`[shipped]`** Pumapayag ako na iproseso ang ID ko para sa pagkumpirma.
      - *en:* I agree to my ID being processed for verification.

## ID review (admin)

- [ ] **`[new]`** ID review
      - *en:* ID review
- [ ] **`[shipped]`** Hindi mabuksan ang queue
      - *en:* Cannot open the queue
- [ ] **`[shipped]`** Walang naghihintay
      - *en:* Nothing waiting
- [ ] **`[shipped]`** Lilitaw dito ang mga bagong ID na ipinadala.
      - *en:* Newly submitted IDs appear here.
- [ ] **`[new]`** Naaprubahan.
      - *en:* Approved.
- [ ] **`[shipped]`** Hindi tinanggap.
      - *en:* Not accepted.
- [ ] **`[shipped]`** Bakit hindi tinanggap?
      - *en:* Why was it not accepted?
- [ ] **`[shipped]`** Hal. Malabo ang litrato, hindi mabasa ang numero.
      - *en:* e.g. Photo is blurry, the number cannot be read.
- [ ] **`[new]`** Kanselahin
      - *en:* Cancel
- [ ] **`[shipped]`** Ipadala
      - *en:* Send
- [ ] **`[new]`** Driver
      - *en:* Driver
- [ ] **`[new]`** Commuter
      - *en:* Commuter
- [ ] **`[new]`** Binubuksan…
      - *en:* Opening…
- [ ] **`[shipped]`** Tingnan ang ID
      - *en:* View the ID
- [ ] **`[shipped]`** Hindi tanggap
      - *en:* Not accepted
- [ ] **`[shipped]`** Aprubahan
      - *en:* Approve

## Driver dashboard and map

- [ ] **`[new]`** Driver
      - *en:* Driver
- [ ] **`[new]`** Walang nakitang driver profile.
      - *en:* No driver profile found.
- [ ] **`[new]`** ID verification
      - *en:* ID verification
- [ ] **`[shipped]`** Ipadala ang lisensya o ID para sa chapter
      - *en:* Send your licence or ID to the chapter
- [ ] **`[new]`** Verified TODA driver
      - *en:* Verified TODA driver
- [ ] **`[new]`** Naka-suspend ang account mo. Hindi ka makakatanggap ng ride.
      - *en:* Your account is suspended. You cannot accept rides.
- [ ] **`[new]`** Hindi natanggap ang registration mo.
      - *en:* Your registration was rejected.
- [ ] **`[new]`** Hinihintay ang verification. Kailangan ka munang aprubahan ng admin bago ka makatanggap ng ride.
      - *en:* Pending verification. An admin must approve you before you can accept rides.
- [ ] **`[new]`** {name} • {plate}
      - *en:* {name} • {plate}
- [ ] **`[new]`** ★ {average} ({count})
      - *en:* ★ {average} ({count})
- [ ] **`[new]`** Online
      - *en:* Online
- [ ] **`[new]`** Offline
      - *en:* Offline
- [ ] **`[new]`** Nakikita ng malapit na commuter ang location mo
      - *en:* Your location is visible to nearby commuters
- [ ] **`[new]`** Mag-online para makatanggap ng ride offer
      - *en:* Go online to receive ride offers
- [ ] **`[new]`** Kasalukuyang biyahe
      - *en:* Current ride
- [ ] **`[new]`** Tawagan si {name}
      - *en:* Call {name}
- [ ] **`[new]`** Simulan ang biyahe
      - *en:* Start trip
- [ ] **`[new]`** Tapusin ang biyahe
      - *en:* Complete ride
- [ ] **`[new]`** Kanselahin
      - *en:* Cancel
- [ ] **`[new]`** Naghihintay ng biyahe
      - *en:* Waiting for a ride
- [ ] **`[new]`** Naka-offline ka
      - *en:* You are offline
- [ ] **`[new]`** Ioofer sa iyo ang pinakamalapit na booking pagdating nito. Panatilihing bukas ang screen na ito.
      - *en:* You will be offered the nearest booking as soon as one comes in. Keep this screen open.
- [ ] **`[new]`** Mag-online sa itaas para makatanggap ng ride offer.
      - *en:* Go online above to start receiving ride offers.
- [ ] **`[new]`** Bagong ride offer
      - *en:* New ride offer
- [ ] **`[new]`** {from}  →  {to}
      - *en:* {from}  →  {to}
- [ ] **`[new]`** Tanggihan
      - *en:* Decline
- [ ] **`[new]`** Tanggapin
      - *en:* Accept
- [ ] **`[new]`** Mag-report ng problema
      - *en:* Report a problem
- [ ] **`[new]`** Sunduin sa {place}
      - *en:* Pick up at {place}
- [ ] **`[new]`** Ibaba sa {place}
      - *en:* Drop off at {place}
- [ ] **`[new]`** {km} km
      - *en:* {km} km
- [ ] **`[new]`** Buksan sa maps
      - *en:* Open in maps
- [ ] **`[new]`** Walang maps app. Destinasyon: {lat}, {lng}
      - *en:* No maps app available. Destination: {lat}, {lng}

## Driver registration and staff sign-in

- [ ] **`[new]`** Driver registration
      - *en:* Driver registration
- [ ] **`[new]`** Ang bagong account ay Pending muna. May TODA admin na magbe-verify sa iyo bago ka makatanggap ng biyahe.
      - *en:* New accounts start as Pending. A TODA admin verifies you before you can accept rides.
- [ ] **`[new]`** Detalye mo
      - *en:* Your details
- [ ] **`[shipped]`** Pangalan
      - *en:* First name
- [ ] **`[new]`** Apelyido
      - *en:* Last name
- [ ] **`[new]`** Mobile number
      - *en:* Mobile number
- [ ] **`[new]`** Ito ang tatawagan ng commuter kapag tinanggap mo.
      - *en:* Commuters call this number when you accept.
- [ ] **`[new]`** Tricycle mo
      - *en:* Your tricycle
- [ ] **`[new]`** Plate number
      - *en:* Plate number
- [ ] **`[new]`** Ipapakita sa commuter para makita ka nila.
      - *en:* Shown to the commuter so they find you.
- [ ] **`[new]`** TODA chapter
      - *en:* TODA chapter
- [ ] **`[new]`** Sign-in
      - *en:* Sign-in
- [ ] **`[new]`** Email
      - *en:* Email
- [ ] **`[new]`** Maglagay ng tamang email address
      - *en:* Enter a valid email address
- [ ] **`[new]`** Password
      - *en:* Password
- [ ] **`[new]`** Hindi bababa sa 6 na karakter.
      - *en:* At least 6 characters.
- [ ] **`[new]`** Ipakita ang password
      - *en:* Show password
- [ ] **`[new]`** Itago ang password
      - *en:* Hide password
- [ ] **`[new]`** Gumamit ng hindi bababa sa 6 na karakter
      - *en:* Use at least 6 characters
- [ ] **`[new]`** Gumawa ng account
      - *en:* Create account
- [ ] **`[new]`** Ilagay ang {label}
      - *en:* Enter your {label}
- [ ] **`[new]`** Mag-sign in
      - *en:* Sign in
- [ ] **`[new]`** Maligayang pagbabalik
      - *en:* Welcome back
- [ ] **`[new]`** Dito nagsa-sign in ang mga driver at administrator. Nakadepende sa account mo kung saan ka mapupunta.
      - *en:* Drivers and administrators sign in here. Where you land depends on your account.
- [ ] **`[new]`** Ilagay ang email na ginamit mo sa pagpaparehistro
      - *en:* Enter the email you registered with
- [ ] **`[new]`** Hindi bababa sa 6 na karakter
      - *en:* At least 6 characters
- [ ] **`[new]`** Magparehistro bilang TODA driver
      - *en:* Register as a TODA driver

## Admin dashboard and email confirmation

- [ ] **`[new]`** Admin
      - *en:* Admin
- [ ] **`[new]`** Feedback
      - *en:* Feedback
- [ ] **`[new]`** Dispatch
      - *en:* Dispatch
- [ ] **`[new]`** ID review
      - *en:* ID review
- [ ] **`[new]`** Naghihintay ng verification
      - *en:* Pending verification
- [ ] **`[new]`** Walang naghihintay ng review
      - *en:* Nothing waiting for review
- [ ] **`[new]`** Lilitaw dito ang mga bagong driver registration.
      - *en:* New driver registrations appear here.
- [ ] **`[new]`** Lahat ng driver ({count})
      - *en:* All drivers ({count})
- [ ] **`[new]`** Wala pang driver
      - *en:* No drivers yet
- [ ] **`[new]`** Nakalista dito ang mga aprubado at naka-suspend na driver.
      - *en:* Approved and suspended drivers are listed here.
- [ ] **`[new]`** Namarkahan ang driver bilang {status}.
      - *en:* Driver marked {status}.
- [ ] **`[new]`** {plate} • {phone}
      - *en:* {plate} • {phone}
- [ ] **`[new]`** {email} ⏎ {chapter}
      - *en:* {email} ⏎ {chapter}
- [ ] **`[new]`** ★ {average} mula sa {count} rating
      - *en:* ★ {average} from {count} ratings
- [ ] **`[shipped]`** Aprubahan
      - *en:* Approve
- [ ] **`[new]`** I-suspend
      - *en:* Suspend
- [ ] **`[new]`** Naipadala ang verification email.
      - *en:* Verification email sent.
- [ ] **`[new]`** Hindi pa rin nakumpirma. Buksan ang link sa email, tapos tingnan ulit.
      - *en:* Still not confirmed. Open the link in the email, then check again.
- [ ] **`[new]`** ang address mo
      - *en:* your address
- [ ] **`[new]`** Kumpirmahin ang email mo
      - *en:* Confirm your email
- [ ] **`[new]`** Kumpirmahin ang email mo para mabuksan ang admin panel
      - *en:* Confirm your email to open the admin panel
- [ ] **`[new]`** Ang pag-sign up ay hindi patunay na sa iyo ang address, kaya hindi ka bibigyan ng admin access ng server hangga't hindi nakukumpirma ang {email}.
      - *en:* Signing up does not prove you own an address, so the server will not grant admin access until {email} is confirmed.
- [ ] **`[new]`** Ipadala ulit sa {seconds}s
      - *en:* Send again in {seconds}s
- [ ] **`[new]`** Ipadala ulit
      - *en:* Send again
- [ ] **`[new]`** Ipadala ang verification email
      - *en:* Send verification email
- [ ] **`[new]`** Nakumpirma ko na
      - *en:* I have confirmed it
- [ ] **`[new]`** Tingnan ang spam kung hindi pa dumadating. Buksan ang link, bumalik dito, tapos pindutin ang "Nakumpirma ko na".
      - *en:* Check spam if it has not arrived. Open the link, come back here, then tap "I have confirmed it".

## Dispatch settings

- [ ] **`[new]`** Dispatch
      - *en:* Dispatch
- [ ] **`[new]`** Na-save ang settings. Live na sa lahat ng phone.
      - *en:* Settings saved. Clients update live.
- [ ] **`[new]`** Nasa server ang mga halagang ito. Ang pagbabago ay tumatalab sa bawat phone sa loob ng ilang segundo — hindi kailangan ng bagong bersyon ng app.
      - *en:* These values live on the server. Changing them takes effect on every phone within seconds — no new app version needed.
- [ ] **`[new]`** Matching
      - *en:* Matching
- [ ] **`[new]`** Search radius (km)
      - *en:* Search radius (km)
- [ ] **`[new]`** Hindi kailanman ino-offer ang biyahe sa driver na mas malayo pa rito.
      - *en:* Drivers further than this are never offered the ride.
- [ ] **`[new]`** Offer timeout (segundo)
      - *en:* Offer timeout (seconds)
- [ ] **`[new]`** Gaano katagal sasagot ang isang driver bago lumipat ang paghahanap.
      - *en:* How long one driver has to answer before the search moves on.
- [ ] **`[new]`** Bilang ng driver na susubukan
      - *en:* Drivers to try
- [ ] **`[new]`** Naka-cap sa 10 — tinatanggihan ng security rules ang mas malalim na paghahanap, kaya ang mas malaking numero ay magbubunga lang ng refused na write.
      - *en:* Capped at 10 — the security rules reject a deeper search, so a larger number here would only produce refused writes.
- [ ] **`[new]`** I-save ang settings
      - *en:* Save settings
- [ ] **`[new]`** Maglagay ng numero
      - *en:* Enter a number
- [ ] **`[new]`** Buong numero lang
      - *en:* Whole numbers only
- [ ] **`[new]`** Dapat nasa pagitan ng {min} at {max}
      - *en:* Must be between {min} and {max}
- [ ] **`[new]`** Ihinto ang bagong booking?
      - *en:* Stop new bookings?
- [ ] **`[new]`** Hindi makakapag-book ang mga commuter hangga't hindi mo ito binubuksan ulit. ⏎  ⏎ Natatapos nang normal ang mga biyaheng kasalukuyang tumatakbo — walang maiiwang nakasakay sa tricycle.
      - *en:* Commuters will not be able to book until you turn this back on. ⏎  ⏎ Rides already in progress finish normally — nobody sitting in a tricycle is stranded.
- [ ] **`[new]`** Kanselahin
      - *en:* Cancel
- [ ] **`[new]`** Ihinto ang booking
      - *en:* Stop bookings
- [ ] **`[new]`** Tumatanggap na ulit ng booking.
      - *en:* Bookings resumed.
- [ ] **`[new]`** Huminto ang booking. Matatapos ang mga biyaheng tumatakbo.
      - *en:* Bookings stopped. Rides in progress will finish.
- [ ] **`[new]`** Tumatanggap ng booking
      - *en:* Accepting bookings
- [ ] **`[new]`** Huminto ang booking
      - *en:* Bookings stopped
- [ ] **`[new]`** I-off ito para ihinto ang pilot. Tumatalab ito sa bawat phone sa loob ng ilang segundo, at hindi kailangan ng app update.
      - *en:* Turn this off to halt the pilot. It takes effect on every phone within seconds, and needs no app update.
- [ ] **`[new]`** Hindi makakapag-book ang mga commuter. Natatapos nang normal ang mga biyaheng tumatakbo.
      - *en:* Commuters cannot book. Rides already in progress finish normally.

## Feedback

- [ ] **`[new]`** Feedback
      - *en:* Feedback
- [ ] **`[new]`** Wala pang report
      - *en:* No reports yet
- [ ] **`[new]`** Lilitaw dito ang mga isyu at mungkahing ipinadala mula sa app.
      - *en:* Issues and suggestions sent from the app appear here.
- [ ] **`[new]`** Kailangan ng atensyon ({count})
      - *en:* Needs attention ({count})
- [ ] **`[new]`** Naasikaso na lahat
      - *en:* Everything handled
- [ ] **`[new]`** Walang bukas na report.
      - *en:* No open reports.
- [ ] **`[new]`** Naresolba ({count})
      - *en:* Resolved ({count})
- [ ] **`[new]`** Isyu
      - *en:* Issue
- [ ] **`[new]`** Mungkahi
      - *en:* Suggestion
- [ ] **`[new]`** Tanong
      - *en:* Question
- [ ] **`[new]`** Iba pa
      - *en:* Other
- [ ] **`[new]`** Namarkahang naresolba.
      - *en:* Marked resolved.
- [ ] **`[new]`** Binuksan ulit.
      - *en:* Reopened.
- [ ] **`[new]`** mula sa {role}
      - *en:* from a {role}
- [ ] **`[new]`** Buksan ulit
      - *en:* Reopen
- [ ] **`[new]`** Markahang naresolba
      - *en:* Mark resolved
- [ ] **`[new]`** ngayon lang
      - *en:* just now
- [ ] **`[new]`** {minutes}m ang nakalipas
      - *en:* {minutes}m ago
- [ ] **`[new]`** {hours}h ang nakalipas
      - *en:* {hours}h ago
- [ ] **`[new]`** {days}d ang nakalipas
      - *en:* {days}d ago
- [ ] **`[new]`** Problema
      - *en:* Problem
- [ ] **`[new]`** Mungkahi
      - *en:* Suggestion
- [ ] **`[new]`** Tanong
      - *en:* Question
- [ ] **`[new]`** Iba pa
      - *en:* Other
- [ ] **`[new]`** Salamat! Nakarating sa TODA admin ang report mo.
      - *en:* Thanks! Your report reached the TODA admin.
- [ ] **`[new]`** Sabihin kung ano ang nangyari
      - *en:* Tell us what happened
- [ ] **`[new]`** Napupunta sa TODA administrator mo ang mga report.
      - *en:* Reports go to your TODA administrator.
- [ ] **`[new]`** Ano ang nangyari?
      - *en:* What happened?
- [ ] **`[new]`** Ilarawan ang problema para may magawa ang admin
      - *en:* Describe the problem so an admin can act on it
- [ ] **`[new]`** Contact (opsyonal)
      - *en:* Contact (optional)
- [ ] **`[new]`** Kung gusto mo lang ng sagot.
      - *en:* Only if you want a reply.
- [ ] **`[new]`** Ipadala ang report
      - *en:* Send report

## Analytics

- [ ] **`[new]`** Biyahe
      - *en:* Rides
- [ ] **`[new]`** I-refresh
      - *en:* Refresh
- [ ] **`[new]`** Walang biyahe sa window na ito.
      - *en:* No rides in this window.
- [ ] **`[new]`** Ipinapakita lang ang pinakabagong {cap} biyahe. Bahagi lang ang mga total sa ibaba.
      - *en:* Showing the most recent {cap} rides only. Totals below are partial.
- [ ] **`[new]`** natapos
      - *en:* completed
- [ ] **`[new]`** completion rate
      - *en:* completion rate
- [ ] **`[new]`** kinansela
      - *en:* cancelled
- [ ] **`[new]`** walang nakitang driver
      - *en:* no driver found
- [ ] **`[new]`** average na rating
      - *en:* avg rating
- [ ] **`[new]`** {unrated} sa {completed} natapos na biyahe ang walang rating.
      - *en:* {unrated} of {completed} completed rides went unrated.
- [ ] **`[new]`** Araw-araw
      - *en:* Daily
- [ ] **`[new]`** Kada driver
      - *en:* By driver
- [ ] **`[new]`** Mga biyahe kada araw. Pinakaabalang araw {peak} biyahe. {days} araw ang ipinapakita.
      - *en:* Daily rides. Busiest day {peak} rides. {days} days shown.
- [ ] **`[new]`** Driver
      - *en:* Driver
- [ ] **`[new]`** Tapos
      - *en:* Done
- [ ] **`[new]`** Kinansela
      - *en:* Cancelled
- [ ] **`[new]`** Rating
      - *en:* Rating

---

**327 strings.** 69 already shipped and field-tested, **258 new and unread
by anyone.**

## Settled, so do not re-litigate

These were decided by the project owner on 2026-09-10 and the copy already
follows them. Flag a specific line that breaks a rule; do not reopen the
rule itself.

1. **mo / ka throughout, never po / ninyo** — including when a driver is
   told their account is suspended.
2. **Two languages rather than one mixed one.** The old screens put English
   buttons beside Filipino body text; that is now a language switch in the
   app bar instead of a compromise.
3. **Three removal words kept:** `Alisin` a photo, `Bawiin` a submitted ID,
   `Burahin` an account. Withdrawing consent and erasing data are different
   acts and stay different words.
4. **Lean English on loanwords** — `location` not `lokasyon`, and `book`,
   `code`, `driver`, `profile`, `ID` stay as people say them.

## The question the sheet cannot answer

Would a **tricycle driver in his fifties** understand every `[new]` line on
the driver dashboard on first reading, without asking anyone? Not "is it
correct Filipino" — is it *his* Filipino. Anything needing a second read
should be flagged even when nothing is wrong with it.

## How to apply an edit

Change the Filipino in `lib/l10n/app_fil.arb`, then run `flutter gen-l10n`.
Nothing else needs touching — no screen holds its own copy any more. Fix
the English in `app_en.arb` the same way; the two files share keys and a
test fails if one gains a key the other lacks.
