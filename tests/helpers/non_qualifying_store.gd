extends RefCounted

# Synthetic full board for legacy end-button checks; no player save is read.
func qualifies(_score: int) -> bool:
	return false
