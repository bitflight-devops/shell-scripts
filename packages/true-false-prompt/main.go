package main

import (
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/list"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	appStyle = lipgloss.NewStyle().Padding(1, 2)

	titleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFDF5")).
			Background(lipgloss.Color("#25A065")).
			Padding(0, 1)

	statusMessageStyle = lipgloss.NewStyle().
				Foreground(lipgloss.AdaptiveColor{Light: "#04B575", Dark: "#04B575"}).
				Render
)

type item struct {
	title       string
	description string
}

var (
	itemYes = item{
		title:       "Yes",
		description: "Approve the process",
	}
	itemNo = item{
		title:       "No",
		description: "Reject the process",
	}
)

func (i item) Title() string       { return i.title }
func (i item) Description() string { return i.description }
func (i item) FilterValue() string { return i.title }

type listKeyMap struct {
	approveProcess key.Binding
	rejectProcess  key.Binding
}

func newListKeyMap() *listKeyMap {
	return &listKeyMap{
		approveProcess: key.NewBinding(
			key.WithKeys("y"),
			key.WithHelp("y", itemYes.description),
		),
		rejectProcess: key.NewBinding(
			key.WithKeys("n"),
			key.WithHelp("n", itemNo.description),
		),
	}
}

type model struct {
	list         list.Model
	keys         *listKeyMap
	delegateKeys *delegateKeyMap
}

func newModel(question string) model {
	var (
		delegateKeys = newDelegateKeyMap()
		listKeys     = newListKeyMap()
	)

	// Make initial list of items
	const numItems = 2
	items := make([]list.Item, numItems)

	items[0] = itemYes
	items[1] = itemNo

	// Setup list
	delegate := newItemDelegate(delegateKeys)
	questionList := list.New(items, delegate, 0, 0)
	questionList.Title = question
	questionList.Styles.Title = titleStyle
	questionList.AdditionalFullHelpKeys = func() []key.Binding {
		return []key.Binding{
			listKeys.approveProcess,
			listKeys.rejectProcess,
		}
	}

	return model{
		list:         questionList,
		keys:         listKeys,
		delegateKeys: delegateKeys,
	}
}

func (m model) Init() tea.Cmd {
	return tea.EnterAltScreen
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		h, v := appStyle.GetFrameSize()
		m.list.SetSize(msg.Width-h, msg.Height-v)

	case tea.KeyMsg:
		// Don't match any of the keys below if we're actively filtering.
		if m.list.FilterState() == list.Filtering {
			break
		}

		switch {
		case key.Matches(msg, m.keys.rejectProcess):
			m.delegateKeys.remove.SetEnabled(true)
			return m, nil

		case key.Matches(msg, m.keys.approveProcess):
			m.delegateKeys.remove.SetEnabled(true)
			return m, nil
		}
	}

	// This will also call our delegate's update function.
	newListModel, cmd := m.list.Update(msg)
	m.list = newListModel
	cmds = append(cmds, cmd)

	return m, tea.Batch(cmds...)
}

func (m model) View() string {
	return appStyle.Render(m.list.View())
}

func main() {
	argLength := len(os.Args[1:])
	question := "Are you sure you want to continue?"
	if argLength != 0 {
		question = os.Args[1]
	}
	for i, a := range os.Args[1:] {
		fmt.Printf("Arg %d is %s\n", i+1, a)
	}
	rand.Seed(time.Now().UTC().UnixNano())
	p := tea.NewProgram(newModel(question))
	if _, err := p.StartReturningModel(); err != nil {
		fmt.Println("Error running program:", err)
		os.Exit(1)
	}
}
