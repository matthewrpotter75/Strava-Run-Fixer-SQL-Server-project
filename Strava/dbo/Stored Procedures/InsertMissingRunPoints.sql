CREATE PROCEDURE dbo.InsertMissingRunPoints
(
	@RunDateToEdit VARCHAR(8),
	@RunDateToInsert VARCHAR(8),
	@RunName VARCHAR(100),
	@EditStartTime DATETIME,
	@EditEndTime DATETIME,
	@EditMovingStartTime TIME(7),
	@EditMovingEndTime TIME(7),
	@Debug TINYINT = 1
)
AS
BEGIN

	DECLARE @MaxInitialTime DATETIME,
			@MinInsertTime DATETIME,
			@DateDiffInsertedPoints INT,
			@EditRunTime DATETIME,
			@EditRunBeginId INT,
			@EditRunEndId INT,
			@InsertRunBeginId INT,
			@InsertRunEndId INT,
			@MaxStage1Id INT,
			@MinStage3Id INT;

	BEGIN TRY

		DECLARE @SQL NVARCHAR(2000);

		TRUNCATE TABLE dbo.EditedRun;

		CREATE TABLE #RunToEdit
		(
			Id			INT NOT NULL PRIMARY KEY,
			Lat			DECIMAL(20,12) NOT NULL,
			Lon			DECIMAL(20,12) NOT NULL,
			Ele			DECIMAL(5,2) NULL,
			[Time]		DATETIME NOT NULL,
			HR			INT NULL,
			CAD			INT NULL,
			PreviousLat DECIMAL(20,12), 
			PreviousLon DECIMAL(20,12), 
			PreviousTime DATETIME,
			DiffLat		DECIMAL(20,12), 
			DiffLon		DECIMAL(20,12), 
			DiffTime	INT,
			Dist		DECIMAL(20,12),
			MovingTime  TIME,
			Geog		GEOGRAPHY
		);

		--Insert run to edit into temp table
		SET @SQL = 'INSERT INTO #RunToEdit SELECT * FROM dbo.Run' + @RunDateToEdit + ';';
		EXEC sp_executesql @SQL;

		--Get the minimum datetime from the run to use on the export xml
		SELECT @EditRunTime = MIN([Time]) FROM #RunToEdit;

		IF @Debug = 1
			SELECT @EditRunTime AS EditRunTime;

		CREATE TABLE #RunToInsert
		(
			Id			INT NOT NULL PRIMARY KEY,
			Lat			DECIMAL(20,12) NOT NULL,
			Lon			DECIMAL(20,12) NOT NULL,
			Ele			DECIMAL(5,2) NULL,
			[Time]		DATETIME NOT NULL,
			HR			INT NULL,
			CAD			INT NULL,
			PreviousLat DECIMAL(20,12), 
			PreviousLon DECIMAL(20,12), 
			PreviousTime DATETIME,
			DiffLat		DECIMAL(20,12), 
			DiffLon		DECIMAL(20,12), 
			DiffTime	INT,
			Dist		DECIMAL(20,12),
			MovingTime  TIME,
			Geog		GEOGRAPHY
		);

		--Insert run to insert from into temp table
		SET @SQL = 'INSERT INTO #RunToInsert SELECT * FROM dbo.Run' + @RunDateToInsert + ';';
		EXEC sp_executesql @SQL;

		IF @EditStartTime IS NOT NULL
			SELECT @EditRunBeginId = Id FROM #RunToEdit WHERE [Time] = @EditStartTime;
		ELSE
			SELECT @EditRunBeginId = Id FROM #RunToEdit WHERE MovingTime = @EditMovingStartTime;

		IF @EditEndTime IS NOT NULL
			SELECT @EditRunEndId = Id FROM #RunToEdit WHERE [Time] = @EditEndTime;
		ELSE
			SELECT @EditRunEndId = Id FROM #RunToEdit WHERE MovingTime = @EditMovingEndTime;

		IF @Debug = 1
			SELECT @EditRunBeginId AS EditRunBeginId, @EditRunEndId AS EditRunEndId;

		IF @EditRunBeginId IS NOT NULL AND @EditRunEndId IS NOT NULL
		BEGIN

			--Get Geography field of last point of run to be edited before insert
			DECLARE @OrgPointBegin GEOGRAPHY =
			(
				SELECT Geog
				FROM #RunToEdit
				WHERE Id = @EditRunBeginId --3307
			);

			DECLARE @OrgPointLatBegin DECIMAL(20,12) = (SELECT Lat FROM #RunToEdit WHERE Id = @EditRunBeginId);
			DECLARE @OrgPointLonBegin DECIMAL(20,12) = (SELECT Lon FROM #RunToEdit WHERE Id = @EditRunBeginId);

			IF @Debug = 1
			BEGIN

				SELECT @OrgPointLatBegin AS OrgPointLatBegin;

				SELECT *, @OrgPointBegin.STDistance(Geog) AS DistFromPoint, (Lat - @OrgPointLatBegin) AS DiffLatFromPoint, (Lon - @OrgPointLonBegin) AS DiffLonFromPoint
				FROM #RunToInsert
				WHERE @OrgPointLatBegin > Lat
				ORDER BY DistFromPoint;

			END

			--Get Id of first point of run to be inserted
			;WITH DistFromPoint AS
			(
				SELECT *, @OrgPointBegin.STDistance(Geog) AS DistFromPoint, (Lat - @OrgPointLatBegin) AS DiffLatFromPoint, (Lon - @OrgPointLonBegin) AS DiffLonFromPoint
				FROM #RunToInsert
				WHERE @OrgPointLatBegin > Lat
			),
			DistFromPointRanking AS
			(
				SELECT Id, ROW_NUMBER() OVER (ORDER BY DistFromPoint) AS RowNum
				FROM DistFromPoint
			)
			SELECT @InsertRunBeginId = Id
			FROM DistFromPointRanking
			WHERE RowNum = 1;

			--Get Geography field of first point of run to be edited after insert
			DECLARE @OrgPointEnd GEOGRAPHY =
			(
				SELECT Geog
				FROM #RunToEdit
				WHERE Id = @EditRunEndId --3311
			);

			DECLARE @OrgPointLatEnd DECIMAL(20,12) = (SELECT Lat FROM #RunToEdit WHERE Id = @EditRunEndId);
			DECLARE @OrgPointLonEnd DECIMAL(20,12) = (SELECT Lon FROM #RunToEdit WHERE Id = @EditRunEndId);

			IF @Debug = 1
			BEGIN

				SELECT @OrgPointLonEnd AS OrgPointLonEnd;

				SELECT *, @OrgPointEnd.STDistance(Geog) AS DistFromPoint, (Lat - @OrgPointLatEnd) AS DiffLatFromPoint, (Lon - @OrgPointLonEnd) AS DiffLonFromPoint
				FROM #RunToInsert
				WHERE Lon < @OrgPointLonEnd
				ORDER BY DistFromPoint;

			END

			--Get Id of last point of run to be inserted
			;WITH DistFromPoint AS
			(
				SELECT *, @OrgPointEnd.STDistance(Geog) AS DistFromPoint, (Lat - @OrgPointLatEnd) AS DiffLatFromPoint, (Lon - @OrgPointLonEnd) AS DiffLonFromPoint
				FROM #RunToInsert
				WHERE Lon < @OrgPointLonEnd
			),
			DistFromPointRanking AS
			(
				SELECT Id, ROW_NUMBER() OVER (ORDER BY DistFromPoint) AS RowNum
				FROM DistFromPoint
			)
			SELECT @InsertRunEndId = Id
			FROM DistFromPointRanking
			WHERE RowNum = 1;

			IF @Debug = 1
				SELECT @InsertRunBeginId AS InsertRunBeginId, @InsertRunEndId AS InsertRunEndId;

			--Insert points before the missing section
			INSERT INTO dbo.EditedRun
			(Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, Stage)
			SELECT Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, 1 AS Stage
			FROM #RunToEdit
			WHERE Id <= @EditRunBeginId --3307
			ORDER BY Id;

			--Insert missing points
			INSERT INTO dbo.EditedRun
			(Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, Stage)
			SELECT Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, 2 AS Stage
			FROM #RunToInsert
			WHERE Id BETWEEN @InsertRunBeginId AND @InsertRunEndId;

			--Insert points after the missing section
			INSERT INTO dbo.EditedRun
			(Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, Stage)
			SELECT Lat, Lon, Ele, [Time], HR, CAD, PreviousLat, PreviousLon, PreviousTime, DiffLat, DiffLon, DiffTime, Dist, MovingTime, Geog, 3 AS Stage
			FROM #RunToEdit
			WHERE Id >= @EditRunEndId --3311
			ORDER BY Id;

			SELECT @MaxInitialTime = MAX([Time]) FROM dbo.EditedRun WHERE Stage = 1;
			SELECT @MinInsertTime = MIN([Time]) FROM dbo.EditedRun WHERE Stage = 2;
			SELECT @DateDiffInsertedPoints = DATEDIFF(s, @MinInsertTime, @MaxInitialTime) + 1;

			IF @Debug = 1
			BEGIN
		
				SELECT 'First split';
				SELECT @MaxInitialTime AS MaxInitialTime, @MinInsertTime AS MinInsertTime, @DateDiffInsertedPoints AS DateDiffInsertedPoints;

			END

			--Adjust time after insertion (inserted points)
			--Get diff in time between end of initial run and beginning of insert and then dateadd to correct time
			UPDATE dbo.EditedRun
			SET [Time] = DATEADD(s, @DateDiffInsertedPoints, [Time])
			WHERE Stage = 2;

			UPDATE r
			SET PreviousLat = prev.Lat, PreviousLon = prev.Lon, PreviousTime = prev.[Time]
			FROM dbo.EditedRun r
			INNER JOIN dbo.EditedRun prev
			ON r.Id -1 = prev.Id
			WHERE r.Stage >= 2;

			UPDATE dbo.EditedRun
			SET DiffLat = Lat - PreviousLat, DiffLon = Lon - PreviousLon, DiffTime = DATEDIFF(s, PreviousTime, [Time])
			WHERE Stage = 2;

			UPDATE dbo.EditedRun
			SET Dist = 6371009 * SQRT(SQUARE((DiffLat * PI())/180) + SQUARE(((DiffLon * PI())/180) * COS((((Lat + PreviousLat)/2) * PI())/180)))
			WHERE Stage = 2;

			--Adjust time after insertion (original run points)
			--Get diff in time between end of inserted run and second part of original run and then dateadd to correct time
			SELECT @MaxInitialTime = MAX([Time]) FROM dbo.EditedRun WHERE Stage = 2;
			SELECT @MinInsertTime = MIN([Time]) FROM dbo.EditedRun WHERE Stage = 3;
			SELECT @DateDiffInsertedPoints = DATEDIFF(s, @MinInsertTime, @MaxInitialTime) + 1;

			IF @Debug = 1
			BEGIN

				SELECT 'Second split';
				SELECT @MaxInitialTime AS MaxInitialTime, @MinInsertTime AS MinInsertTime, @DateDiffInsertedPoints AS DateDiffInsertedPoints

			END

			UPDATE dbo.EditedRun
			SET [Time] = DATEADD(s, @DateDiffInsertedPoints, [Time])
			WHERE Stage = 3;

			UPDATE r
			SET PreviousLat = prev.Lat, PreviousLon = prev.Lon, PreviousTime = prev.[Time]
			FROM dbo.EditedRun r
			INNER JOIN dbo.EditedRun prev
			ON r.Id -1 = prev.Id
			WHERE r.Stage = 3;

			UPDATE dbo.EditedRun
			SET DiffLat = Lat - PreviousLat, DiffLon = Lon - PreviousLon, DiffTime = DATEDIFF(s, PreviousTime, [Time])
			WHERE Stage = 3;

			UPDATE dbo.EditedRun
			SET Dist = 6371009 * SQRT(SQUARE((DiffLat * PI())/180) + SQUARE(((DiffLon * PI())/180) * COS((((Lat + PreviousLat)/2) * PI())/180)))
			WHERE Stage = 3;

			IF @Debug = 1
			BEGIN

				SELECT 'Checking ave speeds';

				SELECT *,
				CASE WHEN DiffTime > 0 THEN Dist/DiffTime ELSE 0 END  AS AveSpeed,
				ROW_NUMBER() OVER (PARTITION BY Stage ORDER BY Id) AS RowNumInStage
				FROM dbo.EditedRun
				ORDER BY AveSpeed DESC;

				SELECT 'Final edited run';

				SELECT *,
				CASE WHEN DiffTime > 0 THEN Dist/DiffTime ELSE 0 END  AS AveSpeed,
				ROW_NUMBER() OVER (PARTITION BY Stage ORDER BY Id) AS RowNumInStage
				FROM dbo.EditedRun;

			END

			--Exporting to GPX XML
			IF @EditRunTime IS NOT NULL AND @RunName IS NOT NULL
			BEGIN

				DECLARE @MetadataXML XML =
				(
					SELECT @EditRunTime AS [time]
					FOR XML PATH (''), ROOT ('metadata'), TYPE
				);

				IF @Debug = 1
					SELECT @MetadataXML;

				DECLARE @XML XML;

				SELECT @XML = 
				(
					SELECT 
					  'http://www.topografix.com/GPX/1/1' AS "@xxmlns",
					  'http://www.w3.org/2001/XMLSchema-instance' AS "@xxmlns..xsi",
					  'http://www.garmin.com/xmlschemas/TrackPointExtension/v1' AS "@xxmlns..gpxtpx",
					  'http://www.garmin.com/xmlschemas/GpxExtensions/v3' AS "@xxmlns..gpxx",
					  'Garmin Forerunner 620' AS "@creator",
					  '1.1' AS "@version",
					  'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd' AS "@xsi..schemaLocation",
					  @MetadataXML,
					  (
						SELECT
						@RunName AS [name],
						(
							SELECT
							'' AS dummytag,
							(
								SELECT
								trkpt.Lat AS "@lat", 
								trkpt.Lon AS "@lon", 
								trkpt.Ele AS "ele", 
								trkpt.[Time] AS "time",
								(
									SELECT 
									HR AS "gpxtpx..TrackPointExtension/gpxtpx..hr", 
									CAD AS "gpxtpx..TrackPointExtension/gpxtpx..cad"
									FROM dbo.EditedRun AS extensions
									WHERE extensions.Id = trkpt.Id
									--AND Id <= 1
									--FOR XML AUTO, TYPE, ELEMENTS)
									FOR XML PATH ('extensions'), TYPE, ELEMENTS
								)
								FROM dbo.EditedRun AS trkpt
								--WHERE Id <= 1
								FOR XML PATH ('trkpt'), TYPE, ELEMENTS
							)
							FOR XML PATH ('trkseg'), TYPE, ELEMENTS
						)
						FOR XML PATH ('trk'), TYPE, ELEMENTS
					)
					FOR XML PATH ('gpx'), TYPE, ELEMENTS
				);

				SET @XML = CAST(REPLACE(REPLACE(CAST(@xml AS NVARCHAR(MAX)), 'xxmlns', 'xmlns'),'..',':') AS XML);
				--SET @XML = CAST(REPLACE(CAST(@XML AS NVARCHAR(MAX)),'<dummytag/>','') AS XML);

				--DECLARE @xmlnvarchar NVARCHAR(MAX);
				--SET @xmlnvarchar = CAST(@xml AS NVARCHAR(MAX));
				--SET @xmlnvarchar = REPLACE(@xmlnvarchar,'<dummytag/>','')
				--SELECT @xmlnvarchar;

				SELECT @XML;

			END
			ELSE
			BEGIN

				PRINT 'Export aborted - run name or run time are not supplied!!!';

			END
		END
		ELSE
		BEGIN

			PRINT 'Ids not found. Check moving time input parameters.';

		END

	END TRY
	BEGIN CATCH

		PRINT 'An Error Occurred!!!';

	END CATCH

END