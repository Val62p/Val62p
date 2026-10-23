--!strict
-- Règles du vol d'opportunité et des protections (toutes appliquées côté serveur).
return {
	-- Phase 1 : crochetage, le voleur doit rester près du socle.
	LockpickSeconds = 3,
	StartRange = 12, -- distance max voleur ↔ socle pour lancer
	LockpickRange = 14, -- distance max pendant le crochetage
	-- Phase 2 : transport visible jusqu'à sa propre base.
	CarrySeconds = 45,
	CarryWalkSpeed = 12,
	NormalWalkSpeed = 16,
	-- Zone surveillée de la place centrale : y entrer avec un mème emprunté le renvoie chez son propriétaire.
	-- (rayon défini dans Config.Map.SafeZoneRadius)
	-- Anti-téléportation pendant le transport (studs/s, marge comprise).
	MaxCarrySpeed = 45,
	CheckInterval = 0.2,

	-- Limites anti-répétition.
	ThiefCooldownSeconds = 30,
	PairCooldownSuccessSeconds = 300,
	PairCooldownFailSeconds = 60,
	-- Le dernier mème posé d'une base ne peut jamais être emporté.
	MinPlacedToSteal = 2,

	-- Protections.
	JoinShieldSeconds = 180,
	VictimShieldSeconds = 180,
	ZenToggleCooldownSeconds = 60,
	-- Assurance versée à la victime d'un vol réussi (part du prix du mème).
	InsuranceRatio = 0.3,
}
