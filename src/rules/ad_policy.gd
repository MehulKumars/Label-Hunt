## When ads may be offered. Pure, so the rules are tested. M2: rewarded only, always opt-in; no interstitials.
class_name AdPolicy
extends RefCounted

const CONTINUES_PER_ATTEMPT := 1
const INTERSTITIALS := false


static func can_offer_continue(continues_used: int) -> bool:
	return continues_used < CONTINUES_PER_ATTEMPT
