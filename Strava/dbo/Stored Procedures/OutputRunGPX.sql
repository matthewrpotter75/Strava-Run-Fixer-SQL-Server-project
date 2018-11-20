CREATE PROCEDURE [dbo].[OutputRunGPX]
(
	@Tablename VARCHAR(100),
	@RunName VARCHAR(500),
	@Debug TINYINT = 0
)
AS
BEGIN

	BEGIN TRY

		DECLARE @RunTime DATETIME;
		DECLARE @SQL NVARCHAR(2000);

		IF PATINDEX('%;%',@Tablename) = 0 AND PATINDEX('%GO%',@Tablename) = 0
		BEGIN

			TRUNCATE TABLE dbo.TempRunTable;
			
			SELECT @SQL = 'INSERT INTO dbo.TempRunTable SELECT * FROM dbo.' + @Tablename + ';';
			EXEC sp_executesql @SQL;

			SELECT @RunTime = MIN([Time]) FROM dbo.TempRunTable;

			IF @Debug=1
			BEGIN

				SELECT *
				FROM dbo.TempRunTable;

				SELECT @RunTime AS RunTime;

			END

			--Exporting to GPX XML
			IF @RunName IS NOT NULL AND @RunTime IS NOT NULL
			BEGIN

				DECLARE @MetadataXML XML =
				(
					SELECT @RunTime AS [time]
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
									FROM dbo.TempRunTable AS extensions
									WHERE extensions.Id = trkpt.Id
									--AND Id <= 1
									--FOR XML AUTO, TYPE, ELEMENTS)
									FOR XML PATH ('extensions'), TYPE, ELEMENTS
								)
								FROM dbo.TempRunTable AS trkpt
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

				PRINT 'RunName and RunTime not populated. Please check these parameters and rerun!!!';

			END

		END
		ELSE
		BEGIN

			PRINT 'Invalid character in @Tablename, possible sql injection attack!!!';

		END

	END TRY
	BEGIN CATCH

		PRINT 'An Error Occurred!!!';

	END CATCH

END