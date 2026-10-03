const test = require('node:test');
const assert = require('node:assert/strict');
const socketCore = require('../../core/socket');

test('Backend Realtime Hub — Admin Socket Events Suite', async (t) => {
  // Mock Socket.io instance
  const emittedEvents = [];
  const mockIO = {
    to: (room) => ({
      emit: (event, payload) => {
        emittedEvents.push({ room, event, payload });
      },
    }),
    emit: (event, payload) => {
      emittedEvents.push({ room: 'all', event, payload });
    },
  };

  // Giả lập gán mockIO cho socket module
  const originalIO = socketCore.getIO();
  // Override internal io reference bằng cách test helper hoặc mock
  socketCore._setMockIO?.(mockIO);

  await t.test('1. emitUserRegistered emits admin.user_registered to admin_room', () => {
    emittedEvents.length = 0;
    const userData = { id: 10, username: 'testuser', fullname: 'Test User' };
    socketCore.emitUserRegistered(userData);
    
    const ev = emittedEvents.find(e => e.event === 'admin.user_registered');
    assert.ok(ev, 'Sự kiện admin.user_registered phải được phát');
    assert.equal(ev.room, 'admin_room');
    assert.equal(ev.payload.username, 'testuser');
  });

  await t.test('2. emitUserLoggedIn emits admin.user_logged_in to admin_room', () => {
    emittedEvents.length = 0;
    const loginData = { idaccount: 10, username: 'testuser', time: new Date().toISOString() };
    socketCore.emitUserLoggedIn(loginData);

    const ev = emittedEvents.find(e => e.event === 'admin.user_logged_in');
    assert.ok(ev, 'Sự kiện admin.user_logged_in phải được phát');
    assert.equal(ev.room, 'admin_room');
    assert.equal(ev.payload.idaccount, 10);
  });

  await t.test('3. emitUserStatusChanged emits admin.user_status_changed to admin_room', () => {
    emittedEvents.length = 0;
    const statusData = { idaccount: 10, status: 'Inactive', reason_inactive: 'Vi phạm' };
    socketCore.emitUserStatusChanged(statusData);

    const ev = emittedEvents.find(e => e.event === 'admin.user_status_changed');
    assert.ok(ev, 'Sự kiện admin.user_status_changed phải được phát');
    assert.equal(ev.room, 'admin_room');
    assert.equal(ev.payload.status, 'Inactive');
  });

  await t.test('4. emitCategoryUpdated emits admin.category_updated to admin_room', () => {
    emittedEvents.length = 0;
    const catData = { action: 'create', category: { id: 5, name: 'Du lịch' } };
    socketCore.emitCategoryUpdated(catData);

    const ev = emittedEvents.find(e => e.event === 'admin.category_updated');
    assert.ok(ev, 'Sự kiện admin.category_updated phải được phát');
    assert.equal(ev.room, 'admin_room');
    assert.equal(ev.payload.action, 'create');
  });

  await t.test('5. emitMaintenanceChanged emits admin.maintenance_changed to admin_room and system.maintenance_changed to all', () => {
    emittedEvents.length = 0;
    const status = { active: true, isEmergency: true };
    socketCore.emitMaintenanceChanged(status);

    const adminEv = emittedEvents.find(e => e.event === 'admin.maintenance_changed');
    assert.ok(adminEv, 'Sự kiện admin.maintenance_changed phải được phát');
    assert.equal(adminEv.room, 'admin_room');

    const allEv = emittedEvents.find(e => e.event === 'system.maintenance_changed');
    assert.ok(allEv, 'Sự kiện system.maintenance_changed phải được phát tới toàn bộ client');
    assert.equal(allEv.room, 'all');
  });

  await t.test('6. emitSystemMetricsStream emits admin.metrics_stream to admin_room', () => {
    emittedEvents.length = 0;
    const metrics = { cpu: 10, ram: 45, eventLoopLagMs: 2, uptimeSeconds: 120 };
    socketCore.emitSystemMetricsStream(metrics);

    const ev = emittedEvents.find(e => e.event === 'admin.metrics_stream');
    assert.ok(ev, 'Sự kiện admin.metrics_stream phải được phát');
    assert.equal(ev.room, 'admin_room');
    assert.equal(ev.payload.cpu, 10);
  });
});
