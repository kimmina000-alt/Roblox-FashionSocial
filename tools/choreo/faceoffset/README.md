# faceoffset (D-1002)

Per-piece facing correction measured against the video (user: "안무 영상 보면서 일일이 비교해서 적용").
No fixed snap to the front: angled, side and back facings stay as danced; only a piece whose
capture is off by a steady amount gets `faceOffset` (ClubChoreo `M.ChoreoFaceOffset`).

1. Pose of the centre member in each rendered clip (tools/choreo/centercut/.venv):

       .venv\Scripts\python.exe clipfront.py ..\centercut\models\yolo11m-pose.pt <song>_centercut\clips out.json "2.mp4,3.mp4,..."

   Every 3rd frame: the person largest and nearest the centre; per row
   [clip seconds, shoulder width / torso height (+ = facing the camera), nose conf, nose offset].
2. Capture facing per piece: capyaw.lua in Studio Play (Client), map clip -> animation id
   (clip local time = piece time), save the output as capyaw.txt.
3. `python offsets.py out.json capyaw.txt`: for the frames where the member faces the camera
   (shoulders at 85 %+ of their widest, nose visible and centred) the capture's facing; its
   median is the error. faceOffset = -median.
4. Use it where |median| >= 6 and the spread (MAD) <= 20; leave pieces whose capture only
   wobbles. Check in Play: hips yaw relative to the root at the front moments is about 0.
5. Clips where other dancers cross in front: clipfront.py follows the member picked before (position + size), and offsets.py needs 12+ front frames; still look at the front frames of any piece with a big offset before using it (BAD 2 clip 9 once gave 65 from a passer-by).
