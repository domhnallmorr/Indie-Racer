# Pace car and pit capacity

The Mile Oval has 26 assignable race stalls and a separate pace-car stall at x=176.043, before the limiter exit at x=195. Existing painted geometry already contained 27 stalls; session.json now exposes the first 26 to rosters and reserves the last. Current roster sizes are unchanged.

The silver, four-door early-2000s saloon is built from native Godot meshes in content/vehicles/pace_car/pace_car_model.gd. It parks in its dedicated bay during practice and qualifying. During race formation it starts 25 metres ahead of pole at rolling speed, follows the reference oval, and adjusts its pace against the actual qualifying leader. Early in Turn 3 the amber roof lights go out and it accelerates toward 140 km/h. It follows a smooth pit-entry curve, brakes for the 80 km/h limit, and eases into its stall.

The field holds its existing two-wide 80 km/h formation. Green requires both the pole sitter reaching the configured green zone and the pace car clearing the track. The pace car is excluded from timing and race positions. During [full-course cautions](cautions.md), it redeploys along the pit exit, picks up the leader and circulates until Race Control calls it in. Caution restarts use single file.

Validation: tools/validate_pace_car.gd covers capacity, bay separation, pace-car gap, pull-away, limiter, green interlock and parking. Run headless with --fixed-fps 120. tools/capture_pace_car.gd renders builds/pace_car_bay.png.
