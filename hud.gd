extends CanvasLayer

func update_lives(value: int) -> void:
	$Lives.text = "Lives: " + str(value)
	
func update_score(value: int) -> void:
	$Score.text = "Score: " + str(value)

func update_message(value: String) -> void:
	$MessageLabel.text = value
