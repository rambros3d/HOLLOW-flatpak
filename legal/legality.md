# Hollow — Legal Landscape Research

*Last updated: May 25, 2026*

Comprehensive research into age verification laws, encryption regulations, and legal liability for encrypted messaging infrastructure providers. Covers the US, UK, and EU.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [United States](#united-states)
   - [KOSA (Kids Online Safety Act)](#kosa-kids-online-safety-act)
   - [State Age Verification Laws](#state-age-verification-laws)
   - [App Store Accountability Acts](#app-store-accountability-acts)
   - [Legal Classification of Hollow](#legal-classification-of-hollow-us)
3. [United Kingdom](#united-kingdom)
   - [Online Safety Act 2023](#online-safety-act-2023)
   - [Section 122 — Client-Side Scanning](#section-122--client-side-scanning)
   - [Investigatory Powers Act (IPA)](#investigatory-powers-act-ipa)
   - [Enforcement to Date](#uk-enforcement-to-date)
4. [European Union](#european-union)
   - [Chat Control (CSAR)](#chat-control-csar)
   - [Digital Services Act (DSA)](#digital-services-act-dsa)
   - [GDPR for Zero-Data Services](#gdpr-for-zero-data-services)
   - [EU Stance on Encryption](#eu-stance-on-encryption)
   - [National Age Verification Efforts](#eu-national-age-verification-efforts)
5. [Key Legal Precedents](#key-legal-precedents)
   - [Windscribe VPN (Greece, 2025)](#windscribe-vpn-greece-2025)
   - [Signal Subpoenas (US, 2016-2025)](#signal-subpoenas-us-2016-2025)
   - [Podchasov v. Russia (ECHR, 2024)](#podchasov-v-russia-echr-2024)
   - [Bernstein v. DOJ (US, 1999)](#bernstein-v-doj-us-1999)
   - [Phil Zimmermann / PGP (1996)](#phil-zimmermann--pgp-1996)
   - [Lavabit (2013)](#lavabit-2013)
   - [Tornado Cash (2024-2025)](#tornado-cash-2024-2025)
   - [The Tor Project](#the-tor-project)
6. [How E2EE Peers Are Handling This](#how-e2ee-peers-are-handling-this)
7. [Hollow's Legal Position](#hollows-legal-position)
8. [Recommendations](#recommendations)

---

## Executive Summary

As of May 2026, **no end-to-end encrypted messaging app has been banned, fined, or forced to add backdoors in the US, UK, or EU.** Not Signal, not Session, not SimpleX, not Briar. The legal landscape is broadly favorable for encrypted, zero-knowledge infrastructure.

Hollow's architecture — E2EE with per-user Ed25519 keys, RAM-only relay that cannot decrypt content, zero metadata storage, no accounts, no phone numbers — places it in the lightest regulatory tier under every existing legal framework.

Age verification laws target **social media platforms** (services with public user-generated content, algorithmic recommendation, community forums). Encrypted private messaging apps have explicit carve-outs or are excluded by definition in every major law.

The strongest legal protections come from:
- **Podchasov v. Russia (ECHR, 2024):** Encryption backdoors violate fundamental human rights. Binding on 46 countries.
- **Section 230 (US):** Conduit providers not liable for transmitted content.
- **EU E-Commerce Directive, Article 12:** "Mere conduit" providers not liable for content they didn't initiate, select, or modify.
- **Windscribe (2025):** RAM-only, no-logs infrastructure operator acquitted.
- **Signal subpoenas:** "We designed it so we cannot comply" accepted by US courts.

---

## United States

### KOSA (Kids Online Safety Act)

**Status: NOT law.** The Senate passed KOSA 91-3 in July 2024, but it died in the 118th Congress without a House vote. Reintroduced in the 119th Congress (S.1748, May 2025). A House companion (KIDS Act, H.R.6484) advanced from subcommittee in March 2026 but gutted the Senate version's "duty of care" provision. As of May 2026, not signed into law.

**What it would require (Senate version):**
- Platforms must provide minors with options to protect their information
- Duty of care to prevent and mitigate specific harms to minors
- FTC enforcement with rulemaking authority
- Threshold: 10M+ monthly active US users providing community forums for user-generated content

**Critical: Direct messaging services are explicitly exempt** as long as they focus on private communication (not public posting) and are not a component of a broader platform. A pure E2EE messaging app like Hollow would fall within this exemption.

### State Age Verification Laws

Roughly half of US states have enacted some form of age verification law. **All target "social media platforms"** defined as services that:
- Allow users to create public profiles
- Publish user-generated content to an audience
- Use algorithmic recommendation/curation
- Provide community forums

Key states with active laws:

| State | Law | Target | Status |
|-------|-----|--------|--------|
| Louisiana | Act 440 | Adult content sites | Active (Jan 2024) |
| Texas | HB 1181 | Adult content sites | Upheld by SCOTUS (June 2025) |
| Utah | SB 287 | Social media | Active (March 2024) |
| Florida | HB 3 | Social media | Active (Jan 2025) |
| Virginia | SB 854 | Social media | Active (July 2025) |
| California | SB 976 | Social media | Active, AV by Dec 2026 |
| Mississippi | HB 1126 | Social media | Active, SCOTUS refused to block |
| Tennessee | HB 1891 | Social media | Active (2024) |
| Alabama | HB 235 | Social media | Active (2025) |

**No E2EE messaging app has been required to implement age verification in any US state.** Signal's terms require users to be 13+ (self-declared), with no additional verification mandated by any jurisdiction.

**The Nevada exception to watch:** Nevada's AG sought a court order to prohibit Meta from enabling E2EE in Facebook Messenger for users under 18. The court described E2EE as "an essential tool of child predators." The EFF and ACLU filed a brief arguing encryption is essential for children's safety. This case is specific to Meta (a social media company adding E2EE on top), not to dedicated E2EE messaging apps.

### App Store Accountability Acts

A newer generation of laws that push age verification to app stores (Apple/Google), not app developers:

| State | Law | Effective | Notes |
|-------|-----|-----------|-------|
| Utah | SB 142 | May 2026 | Active |
| Texas | SB 2420 | Jan 2026 | **Enjoined** on First Amendment grounds |
| Louisiana | Act 481 | July 2026 | No safe harbor for developers |
| Alabama | HB 161 | Feb 2026 | Active |
| California | AB 1043 (DAAA) | Jan 2027 | Pending |

How they work: Apple/Google verify user age at the OS/app store level and provide an "age signal" to developers. The burden falls primarily on the stores. Apple has already begun implementing this in Utah, Louisiana, and Australia. App developers don't need to build their own age verification.

### Legal Classification of Hollow (US)

US law uses several overlapping classifications:

1. **Interactive Computer Service (Section 230):** Broad — covers most online services. Provides liability immunity for third-party content.

2. **Electronic Communications Service (ECPA):** Services that enable sending/receiving electronic communications. E2EE services that cannot access content have minimal disclosure obligations.

3. **The three-tier hierarchy for age verification laws:**
   - **Social media platforms** (Instagram, TikTok, Discord) — Primary targets of all age verification laws
   - **Communications services** (Signal, Session, Hollow) — Generally exempt due to "direct messaging" carve-outs
   - **Infrastructure providers** (ISPs, VPNs, relay servers) — Explicitly excluded from social media laws

**Hollow's relay = infrastructure provider.** Hollow the app = private communications service. Neither matches any "social media platform" definition in any existing state or federal law.

---

## United Kingdom

### Online Safety Act 2023

Received Royal Assent October 2023, phased in through 2024-2026. Regulates **"user-to-user services"** — any internet service where user-generated content can be encountered by other users. This technically includes messaging apps.

**Age verification is required only for:**
- Services hosting pornographic content
- Services that do not prohibit "primary priority content" (suicide, self-harm promotion, etc.)
- Categorised services (Ofcom's Register, pushed back to July 2026)

**Categorisation thresholds are high:**
- **Category 1** (most duties): 34M UK users + content recommender system, or 7M UK users + content resharing. Estimated 12-16 services only.
- **Categories 2A/2B:** Lesser duties. Estimated 35-60 services total.

All regulated services must conduct illegal content risk assessments and have reporting mechanisms. But **small, low-risk services** need only "basic but important measures" if risk assessment shows low risk.

**Messaging apps are technically in scope** but the practical enforcement risk for a small E2EE app with zero user data is currently very low. SimpleX Chat — the closest comparable to Hollow (no user IDs, no metadata, UK-registered company) — has received **zero enforcement actions or data requests.**

### Section 122 — Client-Side Scanning

The most controversial provision. Empowers Ofcom to issue notices requiring services to scan private messages for CSAM/terrorism content, even on E2EE platforms (client-side scanning).

**Status: DORMANT.** The UK government admitted no technology exists to do this without breaking encryption. The clause remains in the law but:
- No "accredited technology" has been designated
- Ofcom has shown little appetite to activate it
- Signal and WhatsApp both threatened to leave the UK rather than comply
- Neither has been asked to do anything — both still operate in the UK
- Privacy advocates call it a "sword of Damocles" — dormant power that could theoretically be activated

### Investigatory Powers Act (IPA)

Separate from the OSA. Allows the Home Office to issue secret **Technical Capability Notices (TCN)** demanding backdoor access to communications.

**The Apple case:**
- Late 2024: Home Office issued a TCN to Apple demanding backdoor access to iCloud data protected by Advanced Data Protection (ADP)
- Apple withdrew ADP from UK users entirely (February 2025) rather than comply
- Apple appealed to the Investigatory Powers Tribunal
- Under US diplomatic pressure, the UK reportedly withdrew the demand
- A separate challenge by Privacy International and Liberty continues

This is the scarier law — but it targets companies with infrastructure/presence in the UK. It has only been used against Apple so far.

### UK Enforcement to Date

All OSA fines issued as of May 2026 have targeted:

| Target | Fine | Reason |
|--------|------|--------|
| AVS Group Ltd | 1M GBP | Adult websites without age verification |
| Kick | 800K GBP | Age assurance failures |
| 4chan | 20K GBP + 100/day | Failing to respond to Ofcom |
| Im.ge | 20K GBP | Failing to respond to Ofcom |
| Itai | 50K GBP | Age assurance failures |

**Zero fines against any encrypted messaging service.** Maximum penalty is 18M GBP or 10% of global revenue, but this has never been applied to messaging.

---

## European Union

### Chat Control (CSAR)

Proposed regulation to combat CSAM online. Would require messaging services — including E2EE — to scan messages.

**Status as of May 2026:**
- **Chat Control 1.0 (voluntary scanning derogation): DEAD.** European Parliament voted 311-228 to reject extending the ePrivacy derogation on March 26, 2026. It expired April 3, 2026. Platforms can no longer voluntarily scan messages in the EU.
- **Chat Control 2.0 (permanent CSAR): In trilogue negotiations.** Council reached a position in November 2025 (dropped mandatory E2EE scanning). Political trilogues ongoing, targeted for July 2026 deal.
- **Parliament vs. Council split:** Parliament excludes E2EE from scanning, rejects mandatory age verification, demands judicial warrants. Council allows voluntary scanning and age verification.

**Current practical impact: NONE.** There is no legal requirement to scan messages in the EU. The voluntary basis expired. The permanent regulation is still under negotiation.

### Digital Services Act (DSA)

In force since February 2024. Creates a tiered regulatory framework:

**Tier 1 — Intermediary Services (lightest obligations):**
- **Mere conduit:** Transmits or provides access to a communication network. Examples: ISPs, VPNs, DNS, VoIP. Not liable for transmitted content if they didn't initiate, select, or modify it. **Hollow's relay fits here.**
- **Caching:** Temporary storage for transmission efficiency.
- **Hosting:** Stores information at user request.

**Tier 2 — Online Platforms (enhanced obligations):**
- Subset of hosting that stores AND disseminates information to the public.
- **Private messaging services are explicitly excluded:** "Interpersonal communication services, such as emails or private messaging services, fall outside the scope of the definition of online platforms as they are used for interpersonal communication between a finite number of persons determined by the sender."

**Tier 3 — Very Large Online Platforms (VLOPs, heaviest):**
- 45M+ monthly active EU users.
- Currently designated: Google, Meta, Amazon, Apple, TikTok, X, Wikipedia, Booking.com.
- WhatsApp designated VLOP only for its "Channels" feature — private messaging excluded.

**Note on public channels:** If Hollow's public channels disseminate content to unlimited recipients, those specific features could partially fall under "online platform" scope. The private messaging portion remains excluded regardless.

### GDPR for Zero-Data Services

GDPR applies to "processing of personal data." If Hollow genuinely processes no personal data:
- **IP addresses are personal data under GDPR.** But if the relay never logs IPs (not even in access logs), this trigger is removed.
- **Transient RAM processing** (e.g., per-IP rate limiting held in memory only, never persisted) is a gray area. Many lawyers argue it technically counts, but enforcement against ephemeral non-logged processing is practically impossible.
- **Anonymized data** (truly anonymized beyond re-identification) is outside GDPR scope.
- A privacy policy stating "we collect nothing" is still recommended for transparency compliance even if no data is processed.
- **Data Protection Impact Assessment (DPIA):** Only required when processing creates "high risk" — a zero-data service wouldn't trigger this.

### EU Stance on Encryption

Contradictory and actively contested:

**Pro-backdoor (ProtectEU, April 2025):**
- European Commission's "ProtectEU" Internal Security Strategy includes a roadmap for "lawful and effective access to data"
- Technology Roadmap on encryption planned for 2026
- Europol to develop "next generation decryption capability" from 2030
- 89 tech industry signatories signed an open letter against this

**Against backdoors (ECHR ruling + Parliament):**
- **Podchasov v. Russia (ECHR, Feb 2024):** Encryption backdoors violate Article 8 (right to private life). Binding on all 46 Council of Europe member states including all EU + UK.
- Parliament's CSAR mandate explicitly excludes E2EE from scanning.
- Council dropped mandatory E2EE scanning in November 2025 compromise.

**Net assessment:** The Commission wants backdoors. The Parliament and the ECHR oppose them. No backdoor mandate has been enacted. The ECHR precedent currently protects E2EE.

### EU National Age Verification Efforts

No EU country has targeted E2EE messaging apps with age verification:
- **France:** Age verification for social media planned by September 2026.
- **Spain:** Banning social media for under-16, mandatory age verification.
- **Germany:** Considering banning minors from social media, decision postponed to mid-2026.

All target social media platforms (Instagram, TikTok, Snapchat), not encrypted messaging.

The EU Age Verification Blueprint (published July 2025, "feature ready" April 2026) uses zero-knowledge proofs via the EU Digital Identity Wallet. Designed for social media and adult content, not private communications.

---

## Key Legal Precedents

### Windscribe VPN (Greece, 2025)

**Facts:** In 2023, a Windscribe server in Finland was allegedly used to breach a Greek computer system. Greek authorities traced the IP to Windscribe infrastructure and filed criminal charges against CEO Yegor Sak personally for "illegal access to electronic data."

**Ruling (April 11, 2025):** Athens Court dismissed all charges for lack of evidence. Windscribe's RAM-only servers and no-logs policy meant zero user data existed.

**Confirmed again (February 2026):** Dutch authorities seized a Windscribe server and found only a stock Ubuntu install — nothing to extract.

**Relevance to Hollow:** Strongest direct precedent for a zero-data infrastructure provider. RAM-only relay, no logs = cannot be compelled to produce data that doesn't exist. However, note that Sak endured a 2-year legal battle before acquittal — the risk is harassment, not liability.

### Signal Subpoenas (US, 2016-2025)

Signal provides exactly **two data points** in response to subpoenas: (1) date account was created, (2) date it last connected. No message content, no contacts, no groups, no profiles.

Notable cases:
- **Central District of California (2016):** Grand jury subpoena. Two timestamps. No further action.
- **Central District of California (2021):** Same result.
- **District of Columbia (2021-2025):** Grand jury subpoena with gag order. ACLU fought the gag order. Response: two timestamps only.

Published at signal.org/bigbrother.

**Relevance to Hollow:** "We designed it so we cannot comply" is accepted by US courts. Hollow has even less data than Signal (no phone numbers, no account creation dates, no last-connection timestamps).

### Podchasov v. Russia (ECHR, 2024)

**Ruling (February 13, 2024):** The European Court of Human Rights held that encryption backdoor mandates violate Article 8 (right to private life) of the European Convention on Human Rights.

Key quotes:
- Breaking E2EE "would extend beyond targeting specific individuals, affecting all users inclusively"
- Backdoors "could facilitate indiscriminate surveillance practices"

**This is the first time an international court explicitly upheld the necessity of E2EE.** Binding on all 46 Council of Europe member states (all EU members + UK + others).

### Bernstein v. DOJ (US, 1999)

**Ruling:** Judge Patel (1996 district court) ruled encryption source code is protected speech under the First Amendment. Ninth Circuit panel upheld 2-1 in May 1999.

**Current status:** The Ninth Circuit's en banc opinion was **vacated by the Supreme Court in 2000 due to mootness** after Clinton relaxed export controls. It is **persuasive but not binding precedent** — courts can cite it but aren't required to follow it. No subsequent court has overturned the core principle that source code is expressive speech.

### Phil Zimmermann / PGP (1996)

Zimmermann faced a three-year federal criminal investigation for releasing PGP encryption software. The DOJ dropped all charges in January 1996 without filing. The investigation collapsed under the absurdity of prosecuting free software, global availability of strong crypto, and political opposition to mandatory backdoors.

**Relevance:** Publishing encryption software is legal. No developer has been prosecuted for releasing general-purpose encryption tools since.

### Lavabit (2013)

**Facts:** FBI obtained a pen register order targeting one user (Edward Snowden). They demanded Lavabit's **SSL/TLS private key** — which would decrypt ALL 410,000 users' communications.

**What happened:**
1. Founder Ladar Levison provided the key as 11 pages of 4-point type (deliberate defiance)
2. Court held him in contempt ($5,000/day fine)
3. Levison shut down the entire service on August 8, 2013
4. Fourth Circuit upheld contempt on procedural grounds but **did not rule** on whether government can compel encryption key disclosure

**Critical lesson for Hollow:** Lavabit's fatal flaw was a single SSL key that could decrypt all traffic. Hollow has no equivalent — each user has their own Ed25519 keypair. The relay has no decryption capability at all. No master key = no Lavabit problem.

### Tornado Cash (2024-2025)

The critical distinction between "writing code" and "operating a service":

- **Alexey Pertsev (Netherlands):** Convicted May 2024, 64 months. Released February 2025 pending appeal. Court found he was not merely writing code but operating infrastructure he knew was used for money laundering.
- **Roman Storm (US):** Mixed verdict August 2025. Convicted of operating unlicensed money transmitter. Jury deadlocked on money laundering/sanctions.
- **Fifth Circuit (November 2024):** Ruled that immutable smart contracts ("lines of code without ownership") are not sanctionable property — protecting the code itself while allowing prosecution of operators.

**Relevance to Hollow:** An open-source developer publishing encryption tools is in a fundamentally different position from operating a mixing service. The relay is a dumb pipe, not a custodial financial service. No court has held an OSS developer liable for how users use general-purpose encryption software.

### The Tor Project

**The Tor Project has never been prosecuted, fined, or held liable.** Running Tor relays is legal under US law.

However:
- Relay operators face police scrutiny (German police raided Artikel 5 eV in August 2024)
- One Austrian exit relay operator (2013) was convicted for underlying content, not for operating the relay
- No Tor Project developer has ever faced criminal charges for building the software

**Relevance to Hollow:** Privacy infrastructure development is legal. Hollow's relay is lower-risk than Tor exit relays because it's authenticated (Ed25519 signatures) and doesn't act as an open proxy.

---

## How E2EE Peers Are Handling This

| App | Architecture | Age Verification | Legal Challenges | Status |
|-----|-------------|-----------------|-----------------|--------|
| **Signal** | E2EE, phone number required, central servers | Self-declared 13+ only | Subpoenas (provides 2 timestamps) | Operates globally |
| **Session** | E2EE, no phone/email, decentralized (Lokinet) | None | None found | Operates globally |
| **SimpleX** | E2EE, no user IDs at all, decentralized relays | None | UK-registered, zero data requests | Operates globally |
| **Briar** | E2EE, peer-to-peer via Tor, no central servers | None | None found | Operates globally |
| **Element/Matrix** | E2EE optional, federated servers | None | None found | Operates globally |
| **Hollow** | E2EE, Ed25519 keys only, RAM-only relay | None needed | None | Pre-launch |

None of these have implemented age verification. None have been fined or banned. None have been forced to add backdoors.

---

## Hollow's Legal Position

### Why Hollow Is in the Clear

1. **The relay is infrastructure, not a platform.** It transmits encrypted blobs it cannot read. It stores nothing to disk. It's the digital equivalent of a telephone switch or postal sorting facility.

2. **No master key exists.** Unlike Lavabit, there is no single key that decrypts all traffic. Each user has their own Ed25519 keypair. The relay literally cannot comply with a decryption order.

3. **Zero metadata.** No accounts, no emails, no phone numbers, no IP logging, no connection timestamps. Less data than Signal (which at least has phone numbers and two timestamps).

4. **Explicit legal carve-outs protect private messaging.** KOSA exempts direct messaging services. The DSA excludes interpersonal communication from "online platform" definitions. State age verification laws target social media with algorithmic curation.

5. **Open source (AGPL-3.0) provides transparency.** Anyone can verify the relay stores nothing. This is stronger than any privacy policy claim.

6. **Strong precedent.** Windscribe (RAM-only, acquitted), Signal (cannot comply, accepted by courts), Podchasov (backdoors violate human rights), Bernstein (encryption is speech).

### Potential Risks

1. **UK's Section 122 activation.** If Ofcom ever designates "accredited technology" for E2EE scanning, they could theoretically issue a notice. Signal and WhatsApp have said they'd leave the UK. Hollow would face the same choice.

2. **UK Investigatory Powers Act TCN.** Secret notices can demand backdoor access. So far only used against Apple. Would require Hollow to have some UK nexus (servers, company registration, significant UK user base).

3. **EU Chat Control 2.0.** If the final regulation includes E2EE scanning mandates (Parliament opposes, Council retreated), it could affect EU operations. Still under negotiation.

4. **Legal harassment.** Even with perfect legal standing, a provider can be dragged through proceedings (Windscribe: 2 years before acquittal). This is the realistic risk — not liability, but cost of defense.

5. **Public channels feature.** Content visible to unlimited recipients could partially fall under "online platform" definitions in the DSA. The private messaging portion remains excluded.

6. **Future legislation.** The legal landscape could change. Maintaining zero-knowledge architecture is the best hedge.

### The "Dumb Pipe" Defense

Hollow's relay has protection under both US and EU law:

**US — Section 230:** "No provider or user of an interactive computer service shall be treated as the publisher or speaker of any information provided by another information content provider." A relay transmitting encrypted blobs it cannot read is the textbook conduit.

**EU — E-Commerce Directive, Article 12 ("Mere Conduit"):** A service provider is not liable for transmitted information when it:
1. Did not initiate the transmission
2. Did not select the receiver
3. Did not select or modify the information

Hollow's relay meets all three conditions by design — it cannot even inspect the information, let alone select or modify it.

---

## Recommendations

1. **Transparency report page on hollow.anonlisten.com.** "We have received 0 legal requests. Our relay architecture stores no user data." Signal does this — it's cheap credibility and the single best response to skeptics.

2. **Keep the Terms of Use and Privacy Policy updated.** They should clearly state the relay stores nothing and content cannot be accessed by anyone other than the intended recipients.

3. **Maintain the zero-knowledge architecture.** The technical design is the strongest legal protection. Don't add logging, accounts, or metadata storage.

4. **Don't implement age verification proactively.** No legal peer (Signal, Session, SimpleX) has. Doing so could increase legal obligations by implying acceptance of platform-level duties.

5. **Standard response template for legal requests:** "Hollow's relay is a transit-only service that does not store, log, or have the ability to decrypt any user communications. We have no data to provide. Please see our architecture documentation."

6. **Monitor legislative developments.** Key dates:
   - EU CSAR trilogue: targeted July 2026
   - UK Ofcom Categorisation Register: July 2026
   - California DAAA: January 2027
   - EU ProtectEU encryption roadmap: 2026

7. **If ever served with a legal request**, the Windscribe/Signal playbook applies: "We designed it so we cannot comply. Here is the architecture. Here is the source code. We have nothing to hand over."
