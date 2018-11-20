CREATE TABLE [dbo].[Segments] (
    [Id]          INT               IDENTITY (1, 1) NOT NULL,
    [SegmentId]   INT               NOT NULL,
    [SegmentName] VARCHAR (256)     NOT NULL,
    [Lat]         DECIMAL (20, 12)  NOT NULL,
    [Lon]         DECIMAL (20, 12)  NOT NULL,
    [Ele]         DECIMAL (5, 2)    NULL,
    [PreviousLat] DECIMAL (20, 12)  NULL,
    [PreviousLon] DECIMAL (20, 12)  NULL,
    [DiffLat]     DECIMAL (20, 12)  NULL,
    [DiffLon]     DECIMAL (20, 12)  NULL,
    [Dist]        DECIMAL (20, 12)  NULL,
    [Geog]        [sys].[geography] NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);

