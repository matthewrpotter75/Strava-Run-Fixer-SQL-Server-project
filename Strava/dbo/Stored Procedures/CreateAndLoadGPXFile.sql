CREATE PROCEDURE [dbo].[CreateAndLoadGPXFile]
(
	@GPXFilename VARCHAR(1000),
	@RunDate VARCHAR(8),
	@Debug TINYINT = 0
)
AS
BEGIN

	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @SQL NVARCHAR(4000),
			@ParmDefinition NVARCHAR(500),
			@Tablename VARCHAR(100),
			@TablenameXML VARCHAR(100),
			@Rowcount INT,
			@RowcountXML INT;

	BEGIN TRY

		SET @Tablename = 'Run' + @RunDate;
		SET @TablenameXML = 'RunXML' + @RunDate;

		IF PATINDEX('%;%',@Tablename) = 0 AND PATINDEX('%GO%',@Tablename) = 0
		BEGIN

			IF OBJECT_ID(@Tablename, 'U') IS NULL
			BEGIN

				SET @SQL = 
				'CREATE TABLE dbo.' + @TablenameXML + '
				(
					Id			INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
					RunXML		XML NOT NULL
				);
	
				CREATE TABLE dbo.' + @Tablename + '
				(
					Id			INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
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
					Geog		GEOGRAPHY,
					IsAdjustPoint TINYINT NULL DEFAULT 0,
					NumAdjustPoints TINYINT NULL DEFAULT 0,
					IsAdjustHR TINYINT DEFAULT 0

				);';

				IF @Debug = 1
					PRINT @SQL;

				EXEC sp_executesql @SQL;

				PRINT 'TABLES CREATED!!!';

			END

			SET @SQL = 'SELECT @RowcountXML=COUNT(1) FROM dbo.' + @TablenameXML;
			SET @ParmDefinition = N'@RowcountXML INT OUTPUT';

			EXEC sp_executesql @SQL, @ParmDefinition, @RowcountXML OUTPUT;

			IF @RowcountXML = 0
			BEGIN

				SET @SQL =
				'INSERT INTO dbo.' + @TablenameXML + ' (RunXML)
				SELECT xCol
				FROM    
				(	SELECT *    
					FROM OPENROWSET (BULK ''D:\StravaSQL\' + @GPXFilename + ''', SINGLE_CLOB) 
					AS xCol
					) R(xCol);';

				IF @Debug = 1
					PRINT @SQL;

				EXEC sp_executesql @SQL;

				PRINT 'XML table populated!!!';

			END

			SET @SQL = 'SELECT @Rowcount=COUNT(1) FROM dbo.' + @Tablename;
			SET @ParmDefinition = N'@Rowcount INT OUTPUT';

			EXEC sp_executesql @SQL, @ParmDefinition, @Rowcount OUTPUT;

			IF @Rowcount = 0
			BEGIN

				SET @SQL = 
				'DECLARE @xml XML;
	
				SELECT @xml = RunXML FROM dbo.' + @TablenameXML + ';

				;WITH xmlnamespaces(default ''http://www.topografix.com/GPX/1/1'', ''http://www.garmin.com/xmlschemas/TrackPointExtension/v1'' AS gpxtpx)
				INSERT INTO dbo.' + @Tablename + '
				(Lat, Lon, Ele, [Time],HR, CAD)
				SELECT 
					node.value(''@lat'', ''decimal(20,12)'') as lat
					, node.value(''@lon'', ''decimal(20,12)'') as lon
					, node.value(''ele[1]'', ''decimal'') as ele
					--, node.value(''(./strategieWuerfelFeld/Name/text())[1]'',''Varchar(50)'') as [Name]
					, node.value(''time[1]'', ''datetime'') as [time]
					, node.value(''extensions[1]/gpxtpx:TrackPointExtension[1]/gpxtpx:hr[1]'', ''int'') as hr
					, node.value(''extensions[1]/gpxtpx:TrackPointExtension[1]/gpxtpx:cad[1]'', ''int'') as cad
				FROM @XML.nodes(''gpx/trk/trkseg/trkpt'') as xmlTable(node);';

				EXEC sp_executesql @SQL;

				PRINT 'Main Run table populated!!!';

			END

			SET @SQL = 'SELECT @Rowcount=COUNT(1) FROM dbo.' + @Tablename;
			SET @ParmDefinition = N'@Rowcount INT OUTPUT';

			EXEC sp_executesql @SQL, @ParmDefinition, @Rowcount OUTPUT;

			IF @Rowcount > 0
			BEGIN

				SET @SQL = 
				'
				UPDATE r
				SET PreviousLat = prev.Lat, PreviousLon = prev.Lon, PreviousTime = prev.[Time]
				FROM dbo.' + @Tablename + ' r
				INNER JOIN dbo.' + @Tablename + ' prev
				ON r.Id -1 = prev.Id;

				UPDATE dbo.' + @Tablename + '
				SET DiffLat = Lat - PreviousLat, 
				DiffLon = Lon - PreviousLon, 
				DiffTime = DATEDIFF(s, PreviousTime, [Time]),
				MovingTime = CAST(DATEADD(s,Id,''00:00.00'') AS TIME(0));

				UPDATE dbo.' + @Tablename + '
				SET Dist = 6371009 * SQRT(SQUARE((DiffLat * PI())/180) + SQUARE(((DiffLon * PI())/180) * COS((((Lat + PreviousLat)/2) * PI())/180)));

				UPDATE dbo.' + @Tablename + '
				SET Geog = geography::Point(Lat, Lon, 4326);';

				IF @Debug = 1
					PRINT @SQL;

				EXEC sp_executesql @SQL;

				PRINT 'Updated calculated columns in Run table!!!';

			END

		END
		ELSE
		BEGIN

			PRINT 'Invalid character in @Tablename, possible sql injection attack!!!';
			PRINT 'Tablename: ' + ISNULL(@Tablename,'');

		END

	END TRY
	BEGIN CATCH

		  IF @@trancount > 0 ROLLBACK TRANSACTION;
		  DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE();
		  RAISERROR (@msg, 16, 1);
		  RETURN 55555;

	END CATCH

END
