package com.holas.plynkeyboard

import org.junit.Assert.assertEquals
import org.junit.Test

class HoldRepeatControllerTest {
  @Test
  fun startExecutesImmediatelyAndSchedulesInitialRepeat() {
    val scheduler = FakeScheduler()
    var actionCount = 0
    val controller = HoldRepeatController(
      postDelayed = scheduler::postDelayed,
      removeCallbacks = scheduler::removeCallbacks,
      action = { actionCount += 1 },
    )

    controller.start()

    assertEquals(1, actionCount)
    assertEquals(listOf(350L), scheduler.scheduledDelays)
  }

  @Test
  fun scheduledRepeatExecutesAndReschedulesAtRepeatInterval() {
    val scheduler = FakeScheduler()
    var actionCount = 0
    val controller = HoldRepeatController(
      postDelayed = scheduler::postDelayed,
      removeCallbacks = scheduler::removeCallbacks,
      action = { actionCount += 1 },
    )

    controller.start()
    scheduler.runNext()

    assertEquals(2, actionCount)
    assertEquals(listOf(350L, 70L), scheduler.scheduledDelays)
  }

  @Test
  fun stopPreventsQueuedRepeatFromExecuting() {
    val scheduler = FakeScheduler()
    var actionCount = 0
    val controller = HoldRepeatController(
      postDelayed = scheduler::postDelayed,
      removeCallbacks = scheduler::removeCallbacks,
      action = { actionCount += 1 },
    )

    controller.start()
    controller.stop()
    scheduler.runNext()

    assertEquals(1, actionCount)
    assertEquals(1, scheduler.removedCallbacksCount)
  }

  private class FakeScheduler {
    private val queue = ArrayDeque<Runnable>()
    val scheduledDelays = mutableListOf<Long>()
    var removedCallbacksCount = 0
      private set

    fun postDelayed(runnable: Runnable, delayMs: Long) {
      scheduledDelays += delayMs
      queue.addLast(runnable)
    }

    fun removeCallbacks(runnable: Runnable) {
      removedCallbacksCount += 1
      queue.removeAll { it === runnable }
    }

    fun runNext() {
      queue.removeFirstOrNull()?.run()
    }
  }
}
