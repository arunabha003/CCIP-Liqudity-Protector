// Code generated by mockery v2.43.2. DO NOT EDIT.

package mocks

import mock "github.com/stretchr/testify/mock"

// ReaperConfig is an autogenerated mock type for the ReaperChainConfig type
type ReaperConfig struct {
	mock.Mock
}

type ReaperConfig_Expecter struct {
	mock *mock.Mock
}

func (_m *ReaperConfig) EXPECT() *ReaperConfig_Expecter {
	return &ReaperConfig_Expecter{mock: &_m.Mock}
}

// FinalityDepth provides a mock function with given fields:
func (_m *ReaperConfig) FinalityDepth() uint32 {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for FinalityDepth")
	}

	var r0 uint32
	if rf, ok := ret.Get(0).(func() uint32); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(uint32)
	}

	return r0
}

// ReaperConfig_FinalityDepth_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'FinalityDepth'
type ReaperConfig_FinalityDepth_Call struct {
	*mock.Call
}

// FinalityDepth is a helper method to define mock.On call
func (_e *ReaperConfig_Expecter) FinalityDepth() *ReaperConfig_FinalityDepth_Call {
	return &ReaperConfig_FinalityDepth_Call{Call: _e.mock.On("FinalityDepth")}
}

func (_c *ReaperConfig_FinalityDepth_Call) Run(run func()) *ReaperConfig_FinalityDepth_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run()
	})
	return _c
}

func (_c *ReaperConfig_FinalityDepth_Call) Return(_a0 uint32) *ReaperConfig_FinalityDepth_Call {
	_c.Call.Return(_a0)
	return _c
}

func (_c *ReaperConfig_FinalityDepth_Call) RunAndReturn(run func() uint32) *ReaperConfig_FinalityDepth_Call {
	_c.Call.Return(run)
	return _c
}

// NewReaperConfig creates a new instance of ReaperConfig. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewReaperConfig(t interface {
	mock.TestingT
	Cleanup(func())
}) *ReaperConfig {
	mock := &ReaperConfig{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}