package com.eggelcompanion.eggel_companion

import android.service.notification.NotificationListenerService

/**
 * Does nothing itself. Android only lets an app read other apps' media sessions
 * (title, artist, playing state) when it holds notification-listener access, so
 * this service exists to be that grant.
 */
class MediaListenerService : NotificationListenerService()
