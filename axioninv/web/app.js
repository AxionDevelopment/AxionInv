const app = document.getElementById('app');
const playerSlotGrid = document.getElementById('playerSlotGrid');
const secondarySlotGrid = document.getElementById('secondarySlotGrid');
const playerWeightText = document.getElementById('playerWeightText');
const secondaryWeightText = document.getElementById('secondaryWeightText');
const secondaryTitle = document.getElementById('secondaryTitle');
const closeBtn = document.getElementById('closeBtn');

const contextMenu = document.getElementById('contextMenu');
const splitPrompt = document.getElementById('splitPrompt');
const splitAmountInput = document.getElementById('splitAmountInput');
const splitConfirmBtn = document.getElementById('splitConfirmBtn');
const splitCancelBtn = document.getElementById('splitCancelBtn');
const contextUseBtn = document.getElementById('contextUseBtn');
const contextSplitOneBtn = document.getElementById('contextSplitOneBtn');
const contextSplitCustomBtn = document.getElementById('contextSplitCustomBtn');
const itemTooltip = document.getElementById('itemTooltip');

let playerInventory = null;
let secondaryInventory = null;
let secondaryType = null;
let secondaryKey = null;
let secondaryLabel = null;
let itemDefs = {};

let dragging = false;
let draggedSlot = null;
let draggedPanel = null;
let dragGhost = null;
let hoverSlot = null;
let hoverPanel = null;
let dragAmount = null;
let dragMode = 'full';

let rightMouseDown = false;
let rightMouseDownSlot = null;
let rightMouseDownPanel = null;
let rightMouseStartX = 0;
let rightMouseStartY = 0;
let rightClickMoved = false;

let contextMenuSlot = null;

let mouseX = 0;
let mouseY = 0;
let dragFrameRequested = false;

function resetDragState() {
    dragging = false;
    draggedSlot = null;
    draggedPanel = null;
    hoverSlot = null;
    hoverPanel = null;
    dragAmount = null;
    dragMode = 'full';
    rightMouseDown = false;
    rightMouseDownSlot = null;
    rightMouseDownPanel = null;
    rightClickMoved = false;
    removeDragGhost();
    clearHoverVisuals();
    hideItemTooltip();
}

function getInventoryByPanel(panel) {
    if (panel === 'player') return playerInventory;
    if (panel === 'secondary') return secondaryInventory;
    return null;
}

function getItemAt(panel, slot) {
    const inv = getInventoryByPanel(panel);
    return inv?.items?.[String(slot)] || null;
}

function getResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'ax_inventory';
}

async function nui(action, data = {}) {
    const res = await fetch(`https://${getResourceName()}/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    });

    return await res.json();
}

function hideContextMenu() {
    contextMenu.classList.add('hidden');
    contextMenuSlot = null;
}

function showContextMenu(slot, x, y) {
    contextMenuSlot = slot;

    const item = getItemAt('player', slot);
    const def = item ? (itemDefs[item.name] || {}) : {};
    const maxStack = Number(def.stack) || 1;
    const canSplit = maxStack > 1 && item && Number(item.amount) > 1;

    if (contextUseBtn) {
        contextUseBtn.style.display = def.usable === false ? 'none' : '';
    }

    if (contextSplitOneBtn) {
        contextSplitOneBtn.style.display = canSplit ? '' : 'none';
    }

    if (contextSplitCustomBtn) {
        contextSplitCustomBtn.style.display = canSplit ? '' : 'none';
    }

    contextMenu.style.left = `${x}px`;
    contextMenu.style.top = `${y}px`;
    contextMenu.classList.remove('hidden');
}

function showSplitPrompt() {
    splitAmountInput.value = '';
    splitPrompt.classList.remove('hidden');
    setTimeout(() => splitAmountInput.focus(), 0);
}

function hideSplitPrompt() {
    splitPrompt.classList.add('hidden');
}

function createDragGhost(item, x, y) {
    removeDragGhost();

    const def = itemDefs[item.name] || {};
    const modeLabel = dragMode === 'split' ? 'Split' : 'Move';

    dragGhost = document.createElement('div');
    dragGhost.className = 'drag-ghost';
    dragGhost.innerHTML = `
        <div class="drag-ghost-name">${def.label || item.name}</div>
        <div class="drag-ghost-count">x${item.amount}</div>
        <div class="drag-ghost-mode">${modeLabel}</div>
    `;

    document.body.appendChild(dragGhost);
    updateDragGhostPosition(x, y);
}

function updateDragGhostPosition(x, y) {
    if (!dragGhost) return;
    dragGhost.style.left = `${x + 14}px`;
    dragGhost.style.top = `${y + 14}px`;
}

function removeDragGhost() {
    if (dragGhost) {
        dragGhost.remove();
        dragGhost = null;
    }
}

function clearHoverVisuals() {
    document.querySelectorAll('.slot.drag-over').forEach((el) => {
        el.classList.remove('drag-over');
    });

    document.querySelectorAll('.slot.dragging').forEach((el) => {
        el.classList.remove('dragging');
    });
}

function updateHoverVisuals() {
    clearHoverVisuals();

    if (draggedPanel && draggedSlot) {
        const draggedEl = document.querySelector(`.slot[data-panel="${draggedPanel}"][data-slot="${draggedSlot}"]`);
        if (draggedEl) {
            draggedEl.classList.add('dragging');
        }
    }

    if (hoverPanel && hoverSlot) {
        const hoverEl = document.querySelector(`.slot[data-panel="${hoverPanel}"][data-slot="${hoverSlot}"]`);
        if (hoverEl) {
            hoverEl.classList.add('drag-over');
        }
    }
}

function requestDragFrame() {
    if (dragFrameRequested) return;

    dragFrameRequested = true;
    requestAnimationFrame(() => {
        dragFrameRequested = false;

        if (!dragging) return;

        updateDragGhostPosition(mouseX, mouseY);
    });
}

function formatItemWeight(weight, amount = 1) {
    const total = Number(weight || 0) * Number(amount || 1);

    if (total >= 1000) {
        return `${(total / 1000).toFixed(2)} kg`;
    }

    return `${total} g`;
}

function showItemTooltip(item, def, x, y) {
    if (!item || !def || !itemTooltip) return;

    const singleWeight = Number(def.weight || 0);

    itemTooltip.innerHTML = `
        <div class="item-tooltip-title">${def.label || item.name}</div>
        <div class="item-tooltip-meta">
            Weight: ${formatItemWeight(singleWeight)} each<br>
            Stack: ${formatItemWeight(singleWeight, item.amount)} total
        </div>
        <div class="item-tooltip-desc">${def.description || 'No description.'}</div>
    `;

    itemTooltip.classList.remove('hidden');
    moveItemTooltip(x, y);
}

function moveItemTooltip(x, y) {
    if (!itemTooltip || itemTooltip.classList.contains('hidden')) return;

    const offset = 14;
    const tooltipWidth = itemTooltip.offsetWidth || 220;
    const tooltipHeight = itemTooltip.offsetHeight || 80;

    let left = x + offset;
    let top = y + offset;

    if (left + tooltipWidth > window.innerWidth - 10) {
        left = x - tooltipWidth - offset;
    }

    if (top + tooltipHeight > window.innerHeight - 10) {
        top = y - tooltipHeight - offset;
    }

    itemTooltip.style.left = `${left}px`;
    itemTooltip.style.top = `${top}px`;
}

function hideItemTooltip() {
    if (!itemTooltip) return;
    itemTooltip.classList.add('hidden');
}

function renderInventoryPanel(panelName, gridEl, inventory, weightEl) {
    gridEl.innerHTML = '';

    if (!inventory) {
        weightEl.textContent = '0 / 0';
        return;
    }

    weightEl.textContent = `${inventory.currentWeight} g / ${inventory.maxWeight} g`;

    for (let i = 1; i <= inventory.slots; i++) {
        const slotEl = document.createElement('div');
        slotEl.className = 'slot';
        slotEl.dataset.slot = String(i);
        slotEl.dataset.panel = panelName;
        slotEl.draggable = false;

        const item = getItemAt(panelName, i);

        const number = document.createElement('div');
        number.className = 'slot-number';
        number.textContent = i;
        slotEl.appendChild(number);

        if (item) {
            const def = itemDefs[item.name] || {};
            slotEl.classList.add('has-item');

            if (def.image) {
                const icon = document.createElement('img');
                icon.className = 'slot-icon';
                icon.src = `images/${def.image}`;
                icon.alt = def.label || item.name;
                icon.draggable = false;
                icon.addEventListener('dragstart', (e) => e.preventDefault());
                slotEl.appendChild(icon);
            }

            const name = document.createElement('div');
            name.className = 'slot-name';
            name.textContent = def.label || item.name;
            slotEl.appendChild(name);

            const count = document.createElement('div');
            count.className = 'slot-count';
            count.textContent = `x${item.amount}`;
            slotEl.appendChild(count);

            slotEl.addEventListener('mousedown', (event) => {
                hideContextMenu();

                if (event.button === 0) {
                    dragging = true;
                    draggedPanel = panelName;
                    draggedSlot = i;
                    hoverSlot = null;
                    hoverPanel = null;
                    dragMode = 'full';
                    dragAmount = Number(item.amount) || 1;

                    createDragGhost(
                        { ...item, amount: dragAmount },
                        event.clientX,
                        event.clientY
                    );

                    updateHoverVisuals();
                    return;
                }

                if (event.button === 2 && panelName === 'player') {
                    rightMouseDown = true;
                    rightMouseDownSlot = i;
                    rightMouseDownPanel = panelName;
                    rightMouseStartX = event.clientX;
                    rightMouseStartY = event.clientY;
                    rightClickMoved = false;
                }
            });

            slotEl.addEventListener('mouseenter', (event) => {
                if (dragging) return;
                showItemTooltip(item, def, event.clientX, event.clientY);
            });

            slotEl.addEventListener('mousemove', (event) => {
                if (dragging) {
                    hideItemTooltip();
                    return;
                }

                moveItemTooltip(event.clientX, event.clientY);
            });

            slotEl.addEventListener('mouseleave', () => {
                hideItemTooltip();
            });
        } else {
            const empty = document.createElement('div');
            empty.className = 'slot-empty';
            empty.textContent = 'Empty';
            slotEl.appendChild(empty);

            slotEl.addEventListener('mousedown', () => {
                hideContextMenu();
            });
        }

        gridEl.appendChild(slotEl);
    }
}

function render() {
    renderInventoryPanel('player', playerSlotGrid, playerInventory, playerWeightText);
    renderInventoryPanel('secondary', secondarySlotGrid, secondaryInventory, secondaryWeightText);

    if (!secondaryInventory) {
        secondaryTitle.textContent = 'No Container Open';
    } else if (secondaryType === 'drop') {
        secondaryTitle.textContent = 'Ground Drop';
    } else if (secondaryType === 'stash') {
        secondaryTitle.textContent = secondaryLabel || 'Stash';
    } else {
        secondaryTitle.textContent = secondaryLabel || 'Container';
    }

    if (dragging) {
        updateHoverVisuals();
    }
}

function isInventoryEmpty(inventory) {
    if (!inventory) return true;
    if (!inventory.items) return true;

    for (const key in inventory.items) {
        const item = inventory.items[key];
        if (item && Number(item.amount) > 0) {
            return false;
        }
    }

    return true;
}

async function closeIfEmptyDrop() {
    if (secondaryType !== 'drop') {
        return false;
    }

    if (!secondaryInventory || isInventoryEmpty(secondaryInventory)) {
        playerInventory = null;
        secondaryInventory = null;
        secondaryType = null;
        secondaryKey = null;
        secondaryLabel = null;

        resetDragState();
        hideContextMenu();
        hideSplitPrompt();
        hideItemTooltip();
        app.classList.add('hidden');

        await nui('close');
        return true;
    }

    return false;
}

async function handleDrop(targetPanel, targetSlot) {
    if (!dragging || !draggedSlot || !draggedPanel) return;

    const fromPanel = draggedPanel;
    const fromSlot = draggedSlot;
    const toPanel = targetPanel;
    const toSlot = targetSlot;
    const amount = dragAmount;

    resetDragState();

    if (!toPanel || !toSlot || (fromPanel === toPanel && fromSlot === toSlot) || !amount || amount < 1) {
        render();
        return;
    }

    let result = null;

    if (fromPanel === toPanel) {
        if (fromPanel === 'player') {
            result = await nui('moveItem', {
                fromSlot,
                toSlot,
                amount
            });

            if (!result || !result.ok) {
                console.log('move failed:', result?.error || 'unknown error');
                render();
                return;
            }

            playerInventory = result.inventory || null;
            render();
            return;
        }

        if (fromPanel === 'secondary') {
            result = await nui('moveSecondaryItem', {
                fromSlot,
                toSlot,
                amount,
                secondaryType,
                secondaryKey
            });

            if (!result || !result.ok) {
                console.log('move failed:', result?.error || 'unknown error');
                render();
                return;
            }

            secondaryInventory = result.inventory || null;

            if (await closeIfEmptyDrop()) {
                return;
            }

            render();
            return;
        }
    }

    result = await nui('moveItemBetween', {
        fromPanel,
        fromSlot,
        toPanel,
        toSlot,
        amount,
        secondaryType,
        secondaryKey
    });

    if (!result || !result.ok) {
        console.log('move failed:', result?.error || 'unknown error');
        render();
        return;
    }

    playerInventory = result.playerInventory || null;
    secondaryInventory = result.secondaryInventory || null;

    if (await closeIfEmptyDrop()) {
        return;
    }

    render();
}

window.addEventListener('contextmenu', (event) => {
    event.preventDefault();
});

document.addEventListener('dragstart', (event) => {
    event.preventDefault();
});

document.addEventListener('drop', (event) => {
    event.preventDefault();
});

document.addEventListener('mousemove', (event) => {
    mouseX = event.clientX;
    mouseY = event.clientY;

    if (rightMouseDown && !dragging) {
        const dx = Math.abs(event.clientX - rightMouseStartX);
        const dy = Math.abs(event.clientY - rightMouseStartY);

        if (dx > 6 || dy > 6) {
            const item = getItemAt(rightMouseDownPanel, rightMouseDownSlot);

            if (item) {
                const itemAmount = Number(item.amount) || 1;
                const half = Math.floor(itemAmount / 2);

                if (half >= 1) {
                    dragging = true;
                    draggedPanel = rightMouseDownPanel;
                    draggedSlot = rightMouseDownSlot;
                    hoverSlot = null;
                    hoverPanel = null;
                    dragMode = 'split';
                    dragAmount = half;
                    rightClickMoved = true;

                    createDragGhost(
                        { ...item, amount: dragAmount },
                        event.clientX,
                        event.clientY
                    );

                    updateHoverVisuals();
                }
            }
        }
    }

    if (!dragging) return;

    requestDragFrame();

    const slotEl = document.elementFromPoint(event.clientX, event.clientY)?.closest?.('.slot');

    let newHoverSlot = null;
    let newHoverPanel = null;

    if (slotEl) {
        newHoverSlot = Number(slotEl.dataset.slot);
        newHoverPanel = slotEl.dataset.panel;
    }

    if (newHoverSlot !== hoverSlot || newHoverPanel !== hoverPanel) {
        hoverSlot = newHoverSlot;
        hoverPanel = newHoverPanel;
        updateHoverVisuals();
    }
});

document.addEventListener('mouseup', async (event) => {
    if (event.button === 2 && rightMouseDown) {
        const slot = rightMouseDownSlot;
        const panel = rightMouseDownPanel;
        const item = getItemAt(panel, slot);

        if (!rightClickMoved && item && panel === 'player') {
            showContextMenu(slot, event.clientX, event.clientY);
        }

        rightMouseDown = false;
        rightMouseDownSlot = null;
        rightMouseDownPanel = null;
        rightClickMoved = false;
    }

    if (!dragging) return;

    const slotEl = document.elementFromPoint(event.clientX, event.clientY)?.closest?.('.slot');
    const targetSlot = slotEl ? Number(slotEl.dataset.slot) : null;
    const targetPanel = slotEl ? slotEl.dataset.panel : null;

    await handleDrop(targetPanel, targetSlot);
});

document.addEventListener('click', (event) => {
    if (!contextMenu.contains(event.target)) {
        hideContextMenu();
    }
});

contextMenu.addEventListener('click', async (event) => {
    const action = event.target.dataset.action;
    if (!action || !contextMenuSlot) return;

    const slot = contextMenuSlot;
    const item = getItemAt('player', slot);
    hideContextMenu();

    if (!item) return;

    if (action === 'use') {
        const result = await nui('useItem', { slot });
        if (result?.ok && result.inventory) {
            playerInventory = result.inventory;
            render();
        }
        return;
    }

    if (action === 'drop') {
        const result = await nui('dropItem', { slot, amount: item.amount });
        if (result?.ok && result.inventory) {
            playerInventory = result.inventory;
            render();
        }
        return;
    }

    if (action === 'splitOne') {
        const result = await nui('splitOne', { slot });
        if (result?.ok && result.inventory) {
            playerInventory = result.inventory;
            render();
        }
        return;
    }

    if (action === 'splitCustom') {
        contextMenuSlot = slot;
        showSplitPrompt();
    }
});

splitConfirmBtn.addEventListener('click', async () => {
    const slot = contextMenuSlot;
    const item = getItemAt('player', slot);
    const amount = Number(splitAmountInput.value);

    hideSplitPrompt();

    if (!slot || !item || !amount || amount < 1 || amount >= item.amount) {
        return;
    }

    const result = await nui('splitCustom', { slot, amount });
    if (result?.ok && result.inventory) {
        playerInventory = result.inventory;
        render();
    }
});

splitCancelBtn.addEventListener('click', () => {
    hideSplitPrompt();
});

closeBtn.addEventListener('click', async (event) => {
    event.preventDefault();
    event.stopPropagation();

    resetDragState();
    hideContextMenu();
    hideSplitPrompt();
    hideItemTooltip();

    await nui('close');
});

window.addEventListener('keydown', async (event) => {
    if (event.key === 'Escape' || event.key === 'Tab') {
        resetDragState();
        hideContextMenu();
        hideSplitPrompt();
        hideItemTooltip();
        await nui('close');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        playerInventory = data.inventory;
        secondaryInventory = null;
        secondaryType = null;
        secondaryKey = null;
        secondaryLabel = null;
        itemDefs = data.items || {};
        app.classList.remove('hidden');
        render();
        return;
    }

    if (data.action === 'close') {
        playerInventory = null;
        secondaryInventory = null;
        secondaryType = null;
        secondaryKey = null;
        secondaryLabel = null;
        resetDragState();
        hideContextMenu();
        hideSplitPrompt();
        hideItemTooltip();
        app.classList.add('hidden');
        return;
    }

    if (data.action === 'setInventory') {
        playerInventory = data.inventory;
        itemDefs = data.items || {};
        render();
        return;
    }

    if (data.action === 'openSecondaryInventory') {
        playerInventory = data.playerInventory;
        secondaryInventory = data.inventory;
        secondaryType = data.type || 'drop';
        secondaryKey = data.key;
        secondaryLabel = data.label || null;
        itemDefs = data.items || {};
        app.classList.remove('hidden');
        render();
        return;
    }

    if (data.action === 'updateSecondaryInventory') {
        playerInventory = data.playerInventory;
        secondaryInventory = data.inventory;
        secondaryType = data.type || secondaryType;
        secondaryKey = data.key ?? secondaryKey;
        itemDefs = data.items || itemDefs;
        hideContextMenu();
        hideSplitPrompt();
        hideItemTooltip();
        resetDragState();
        render();
        return;
    }
});

window.addEventListener('blur', () => {
    resetDragState();
    hideContextMenu();
    hideSplitPrompt();
    hideItemTooltip();
});